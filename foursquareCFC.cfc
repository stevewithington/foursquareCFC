<!---
	Name: foursquareCFC
	Author: Andy Matthews
	Website: http://www.andyMatthews.net || http://foursquareCFC.riaforge.org
	API Docs: http://groups.google.com/group/foursquare-api/web/api-documentation
	Created: 07/31/2011
	Last Updated: 08/10/2011
	History:
		08/17/2011: Fixed error in return packet under certain circumstances
		07/31/2011: Initial creation of foursquareCFC v2 (mirroring foursquare's shift to oAuth 2)
	Version: Listed in contructor
--->
<cfcomponent hint="CFC allowing users to tap into the foursquare API" displayname="foursquareCFC" output="false">

	<cfscript>
		VARIABLES.version = '2.01';
		VARIABLES.appName = 'foursquareCFC';
		VARIABLES.baseURL = 'https://api.foursquare.com/v2';
		VARIABLES.lastUpdated = DateFormat(CreateDate(2011,08,17),'mm/dd/yyyy');
		VARIABLES.oauth_token = '';
	</cfscript>

	<!---
		################################################################
		##	 INTERNAL METHODS ###########################################
		################################################################
	--->
	<cffunction name="init" description="Initializes the CFC, returns itself" returntype="foursquareCFC" access="public" output="false">
		<cfargument name="oauth_token" type="string" required="true">

		<cfscript>
			VARIABLES.oauth_token = ARGUMENTS.oauth_token;
		</cfscript>

		<cfreturn THIS>
	</cffunction>

	<cffunction name="currentVersion" description="Returns current version" returntype="string" access="public" output="false">
		<cfreturn VARIABLES.version>
	</cffunction>

	<cffunction name="lastUpdated" description="Returns last updated date" returntype="date" access="public" output="false">
		<cfreturn VARIABLES.lastUpdated>
	</cffunction>

	<cffunction name="introspect" description="Returns detailed info about this CFC" returntype="struct" access="public" output="false">
		<cfreturn getMetaData(this)>
	</cffunction>

	<cffunction name="call" description="The actual http call to foursquare" returntype="string" access="private" output="false">
		<cfargument name="attr" required="true" type="struct">
		<cfargument name="params" required="true" type="struct">

		<cfscript>
			var LOCAL = {};
			var cfhttp = {};
			// what fieldtype will this be?
			LOCAL['fieldType'] = iif( ARGUMENTS.attr['method'] == 'GET', De('URL'), De('formField') );
			LOCAL['params'] = Duplicate(ARGUMENTS.params);
			LOCAL['params']['oauth_token'] = VARIABLES.oauth_token;
		</cfscript>
		<!---<cfdump var="#ARGUMENTS#" abort="true">--->
		<cfhttp attributecollection="#ARGUMENTS.attr#">
			<cfloop collection="#LOCAL['params']#" item="LOCAL.key">
				<cfhttpparam name="#LOCAL.key#" type="#LOCAL['fieldType']#" value="#LOCAL['params'][LOCAL.key]#">
			</cfloop>
		</cfhttp>
		<!---<cfdump var="#cfhttp#" abort="true">--->
		<cfreturn cfhttp.fileContent.toString()>
	</cffunction>

	<cffunction name="prep" description="Prepares data for call to foursquare servers" returntype="struct" access="private" output="false">
		<cfargument name="config" type="struct" required="true">

		<cfscript>
			var LOCAL = {};
			LOCAL['cfdata'] = {};
			LOCAL['attributes'] = {};
			LOCAL['returnStruct'] = {};

			// finish setting up the attributes for the http call
			LOCAL['attributes']['url'] = ARGUMENTS['config']['url'];
			LOCAL['attributes']['method'] = ARGUMENTS['config']['method'];

			try {
				LOCAL['jsondata'] = call(LOCAL['attributes'], ARGUMENTS['config']['params']);
				LOCAL['cfdata'] = DeserializeJson(LOCAL['jsondata']);
				// were there any errors?
				if (StructCount(LOCAL['cfdata']['response'])) {
					// no errors, proceed
					if (ARGUMENTS['config']['format'] EQ 'json') {
						LOCAL.returnStruct = pkgStruct(LOCAL['jsondata'], 1, 'Request successful');
					} else {
						LOCAL.returnStruct = pkgStruct(LOCAL['cfdata'], 1, 'Request successful');
					}
				} else {
					// for some reason with flagspecials there's no error detail. Did it work?
					if (StructKeyExists(LOCAL.cfdata.meta,'errorDetail')) {
						// yes there were, get the details
						return pkgStruct('', 0, LOCAL['cfdata']['meta']['errorDetail']);
					} else {
						// return unknown issue
						return pkgStruct('', 0, 'An unknown issue occurred');
					}
				}
			} catch(any e) {
				//set success and message value
				return pkgStruct('', 0, 'An error occurred. Please check your parameters and try your request again.');
			}
		</cfscript>

		<cfreturn LOCAL.returnStruct>
	</cffunction>

	<cffunction name="pkgStruct" description="packages data into a struct for return to user" returntype="struct" access="private" output="false">
		<cfargument name="data" type="any" required="true">
		<cfargument name="success" type="boolean" required="true">
		<cfargument name="message" type="string" required="true">
		<cfscript>
				var LOCAL['return'] = {};
				LOCAL['return']['data'] = ARGUMENTS.data;
				LOCAL['return']['success'] = ARGUMENTS.success;
				LOCAL['return']['message'] = ARGUMENTS.message;
		</cfscript>
		<cfreturn LOCAL['return']>
	</cffunction>




	<!---
		################################################################
		##	 USER METHODS ###############################################
		################################################################
	--->
	<cffunction name="user" description="Returns profile information for a given user, including selected badges and mayorships" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="leaderboard" description="Returns the user's leaderboard" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="neighbors" type="numeric" required="false" hint="Number of friends' scores to return that are adjacent to your score, in ranked order.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/leaderboard';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'neighbors') ) LOCAL['config']['params']['neighbors'] = ARGUMENTS.neighbors;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="searchUser" description="Helps a user locate friends" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="phone" type="string" required="false" hint="A comma-delimited list of phone numbers to look for.">
		<cfargument name="email" type="string" required="false" hint="A comma-delimited list of email addresses to look for.">
		<cfargument name="twitter" type="string" required="false" hint="A comma-delimited list of Twitter handles to look for.">
		<cfargument name="twitterSource" type="string" required="false" hint="A single Twitter handle. Results will be friends of this user who use Foursquare.">
		<cfargument name="fbid" type="string" required="false" hint="A comma-delimited list of Facebook ID's to look for.">
		<cfargument name="name" type="string" required="false" hint="A single string to search for in users' names.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'phone') ) LOCAL['config']['params']['phone'] = ARGUMENTS.phone;
			if ( StructKeyExists(ARGUMENTS,'email') ) LOCAL['config']['params']['email'] = ARGUMENTS.email;
			if ( StructKeyExists(ARGUMENTS,'twitter') ) LOCAL['config']['params']['twitter'] = ARGUMENTS.twitter;
			if ( StructKeyExists(ARGUMENTS,'twitterSource') ) LOCAL['config']['params']['twitterSource'] = ARGUMENTS.twitterSource;
			if ( StructKeyExists(ARGUMENTS,'fbid') ) LOCAL['config']['params']['fbid'] = ARGUMENTS.fbid;
			if ( StructKeyExists(ARGUMENTS,'name') ) LOCAL['config']['params']['name'] = ARGUMENTS.name;

			// this method requires at least one argument
			if (NOT StructCount(LOCAL['config']['params'])) return pkgStruct('', 0, 'You must specify at least one of the search parameters.');
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="requests" description="Shows a user the list of users with whom they have a pending friend request" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/requests';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<!---
		##	 USER ASPECT METHODS ##
	--->
	<cffunction name="badges" description="Returns badges for a given user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/badges';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="checkins" description="Returns a history of checkins for the authenticated user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 250">
		<cfargument name="offset" type="numeric" required="false" hint="The number of results to skip. Used to page through results">
		<cfargument name="afterTimestamp" type="numeric" required="false" hint="Retrieve the first results to follow these seconds since epoch">
		<cfargument name="beforeTimestamp" type="numeric" required="false" hint="Retrieve the first results prior to these seconds since epoch">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/checkins';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
			if ( StructKeyExists(ARGUMENTS,'afterTimestamp') ) LOCAL['config']['params']['afterTimestamp'] = ARGUMENTS.afterTimestamp;
			if ( StructKeyExists(ARGUMENTS,'beforeTimestamp') ) LOCAL['config']['params']['beforeTimestamp'] = ARGUMENTS.beforeTimestamp;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="friends" description="Returns an array of a user's friends" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="limit" type="numeric" required="false" hintint="Number of results to return, up to 250">
		<cfargument name="offset" type="numeric" required="false" hint="The number of results to skip. Used to page through results">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/friends';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="mayorships" description="Returns a user's mayorships" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/mayorships';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="userTips" description="Returns tips from a user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="sort" type="string" required="false" default="recent" hint="One of recent, nearby, or popular. Nearby requires geolat and geolong to be provided">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the user's location">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 250">
		<cfargument name="offset" type="numeric" required="false" hint="The number of results to skip. Used to page through results">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/tips';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'sort') ) {
				if ( NOT ListFindNoCase('recent,nearby,popular',ARGUMENTS.sort) ) {
					// if nearby is specified, then lat and long are required
					 return pkgStruct('', 0, 'Sort must be either "recent", "nearby", or "popular".');
				}
				if (ARGUMENTS.sort IS 'nearby' AND NOT StructKeyExists(ARGUMENTS,'ll')) {
					// if nearby is specified, then lat and long are required
					 return pkgStruct('', 0, 'When sort is set to "nearby" then lat and long are required.');
				}
			}
			if ( StructKeyExists(ARGUMENTS,'ll') ) LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="todos" description="Returns todos from a user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="sort" type="string" required="false" default="recent" hint="One of nearby or recent. Nearby requires geolat and geolong to be provided">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the user's location">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/todos';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if (ARGUMENTS.sort IS 'nearby' AND NOT StructKeyExists(ARGUMENTS,'ll')) {
				// if nearby is specified, then lat and long are required
				 return pkgStruct('', 0, 'When sort is set to "nearby" then lat and long are required.');
			}
			if ( StructKeyExists(ARGUMENTS,'ll') ) LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'sort') ) LOCAL['config']['params']['sort'] = ARGUMENTS.sort;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="venuehistory" description="Returns a list of all venues visited by the specified user, along with how many visits and when they were last there" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="beforeTimestamp" type="numeric" required="false" hint="Seconds since epoch">
		<cfargument name="afterTimestamp" type="numeric" required="false" hint="Seconds after epoch">
		<cfargument name="categoryId" type="string" required="false" hint="Limits returned venues to those in this category. If specifying a top-level category, all sub-categories will also match the query">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/venuehistory';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'beforeTimestamp') ) LOCAL['config']['params']['beforeTimestamp'] = ARGUMENTS.beforeTimestamp;
			if ( StructKeyExists(ARGUMENTS,'afterTimestamp') ) LOCAL['config']['params']['afterTimestamp'] = ARGUMENTS.afterTimestamp;
			if ( StructKeyExists(ARGUMENTS,'categoryId') ) LOCAL['config']['params']['categoryId'] = ARGUMENTS.categoryId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<!---
		##	 USER ACTION METHODS ##
	--->
	<cffunction name="request" description="Sends a friend request to another user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/request';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="unfriend" description="Cancels any relationship between the acting user and the specified user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/unfriend';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="approve" description="Approves a pending friend request from another user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/approve';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="deny" description="Denies a pending friend request from another user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/deny';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="setpings" description="Changes whether the acting user will receive pings (phone notifications) when the specified user checks in." returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="user_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="value" type="boolean" required="true">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/' & ARGUMENTS.user_id & '/setpings';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['value'] = ARGUMENTS.value;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="update" description="Updates the user's profile photo." returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="photo" type="any" required="true" hint="Photo under 100KB in multipart MIME encoding with content type image/jpeg, image/gif, or image/png.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/users/self/update';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['photo'] = ARGUMENTS.photo;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 VENUE METHODS ##############################################
		################################################################
	--->
	<cffunction name="venue" description="Gives details about a venue, including location, mayorship, tags, tips, specials, and category" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="addVenue" description="Allows users to add a new venue" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="name" type="string" required="true">
		<cfargument name="ll" type="string" required="true" hint="Latitude and longitude of the venue, as accurate as is known">
		<cfargument name="address" type="string" required="false" hint="The address of the venue">
		<cfargument name="crossStreet" type="string" required="false" hint="The nearest intersecting street or streets">
		<cfargument name="city" type="string" required="false" hint="The city name where this venue is">
		<cfargument name="state" type="string" required="false" hint="The nearest state or province to the venue">
		<cfargument name="zip" type="string" required="false" hint="The zip or postal code for the venue">
		<cfargument name="phone" type="string" required="false" hint="The phone number of the venue">
		<cfargument name="primaryCategoryId" type="string" required="false" hint="The ID of the category to which you want to assign this venue">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/add';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['name'] = ARGUMENTS.name;
			LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'address') ) LOCAL['config']['params']['address'] = ARGUMENTS.address;
			if ( StructKeyExists(ARGUMENTS,'crossStreet') ) LOCAL['config']['params']['crossStreet'] = ARGUMENTS.crossStreet;
			if ( StructKeyExists(ARGUMENTS,'city') ) LOCAL['config']['params']['city'] = ARGUMENTS.city;
			if ( StructKeyExists(ARGUMENTS,'state') ) LOCAL['config']['params']['state'] = ARGUMENTS.state;
			if ( StructKeyExists(ARGUMENTS,'zip') ) LOCAL['config']['params']['zip'] = ARGUMENTS.zip;
			if ( StructKeyExists(ARGUMENTS,'phone') ) LOCAL['config']['params']['phone'] = ARGUMENTS.phone;
			if ( StructKeyExists(ARGUMENTS,'primaryCategoryId') ) LOCAL['config']['params']['primaryCategoryId'] = ARGUMENTS.primaryCategoryId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="categories" description="Returns a hierarchical list of categories applied to venues" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/categories';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="explore" description="Returns a list of recommended venues near the current location" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="ll" type="string" required="true" hint="Latitude and longitude of the user's location, so response can include distance">
		<cfargument name="llAcc" type="numeric" required="false" hint="Accuracy of latitude and longitude, in meters">
		<cfargument name="alt" type="numeric" required="false" hint="Altitude of the user's location, in meters">
		<cfargument name="altAcc" type="numeric" required="false" hint="Accuracy of the user's altitude, in meters">
		<cfargument name="radius" type="numeric" required="false" hint="Radius to search within, in meters">
		<cfargument name="section" type="string" required="false" hint="One of 'food', 'drinks', 'coffee', 'shops', or 'arts'. Choosing one of these limits results to venues with categories matching these terms">
		<cfargument name="query" type="string" required="false" hint="A search term to be applied against tips, category, tips, etc. at a venue">
		<cfargument name="limit" type="string" required="false" hint="Number of results to return, max of 50">
		<cfargument name="intent" type="string" required="false" hint="Limit results to venues with specials. It's stackable">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/explore';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'llAcc') ) LOCAL['config']['params']['llAcc'] = ARGUMENTS.llAcc;
			if ( StructKeyExists(ARGUMENTS,'alt') ) LOCAL['config']['params']['alt'] = ARGUMENTS.alt;
			if ( StructKeyExists(ARGUMENTS,'altAcc') ) LOCAL['config']['params']['altAcc'] = ARGUMENTS.altAcc;
			if ( StructKeyExists(ARGUMENTS,'radius') ) LOCAL['config']['params']['radius'] = ARGUMENTS.radius;
			if ( StructKeyExists(ARGUMENTS,'section') AND NOT ListFindNoCase('food,drinks,coffee,shops,arts',ARGUMENTS.section)) {
				// if section is specified, then section must be a specific string
				 return pkgStruct('', 0, 'Section must be either "food", "drinks", "coffee", "shops", or "arts".');
			}
			if ( StructKeyExists(ARGUMENTS,'query') ) LOCAL['config']['params']['query'] = ARGUMENTS.query;
			if ( StructKeyExists(ARGUMENTS,'section') ) LOCAL['config']['params']['section'] = ARGUMENTS.section;
			if ( StructKeyExists(ARGUMENTS,'intent') ) LOCAL['config']['params']['intent'] = ARGUMENTS.intent;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="searchVenue" description="Returns a list of venues near the current location, optionally matching the search term" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="ll" type="string" required="true" hint="Latitude and longitude of the user's location, so response can include distance">
		<cfargument name="llAcc" type="numeric" required="false" hint="Accuracy of latitude and longitude, in meters">
		<cfargument name="alt" type="numeric" required="false" hint="Altitude of the user's location, in meters">
		<cfargument name="altAcc" type="numeric" required="false" hint="Accuracy of the user's altitude, in meters">
		<cfargument name="radius" type="numeric" required="false" hint="Radius to search within, in meters">
		<cfargument name="section" type="string" required="false" hint="One of 'food', 'drinks', 'coffee', 'shops', or 'arts'. Choosing one of these limits results to venues with categories matching these terms">
		<cfargument name="query" type="string" required="false" hint="A search term to be applied against tips, category, tips, etc. at a venue">
		<cfargument name="limit" type="string" required="false" hint="Number of results to return, max of 50">
		<cfargument name="intent" type="string" required="false" hint="Limit results to venues with specials. It's stackable">
		<cfargument name="categoryId" type="string" required="false" hint="A category to limit results to">
		<cfargument name="url" type="string" required="false" hint="A third-party URL which we will attempt to match against our map of venues to URLs. This is an experimental API and subject to change or breakage.">
		<cfargument name="providerId" type="string" required="false" hint="Identifier for a known third party that is part of our map of venues to URLs, used in conjunction with linkedId. This is an experimental API and subject to change or breakage">
		<cfargument name="linkedId" type="string" required="false" hint="1002207971611 Identifier used by third party specifed in providerId, which we will attempt to match against our map of venues to URLs. This is an experimental API and subject to change or breakage">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'llAcc') ) LOCAL['config']['params']['llAcc'] = ARGUMENTS.llAcc;
			if ( StructKeyExists(ARGUMENTS,'alt') ) LOCAL['config']['params']['alt'] = ARGUMENTS.alt;
			if ( StructKeyExists(ARGUMENTS,'altAcc') ) LOCAL['config']['params']['altAcc'] = ARGUMENTS.altAcc;
			if ( StructKeyExists(ARGUMENTS,'radius') ) LOCAL['config']['params']['radius'] = ARGUMENTS.radius;
			if ( StructKeyExists(ARGUMENTS,'section') AND NOT ListFindNoCase('food,drinks,coffee,shops,arts',ARGUMENTS.section)) {
				// if section is specified, then section must be a specific string
				 return pkgStruct('', 0, 'Section must be either "food", "drinks", "coffee", "shops", or "arts".');
			}
			if ( StructKeyExists(ARGUMENTS,'query') ) LOCAL['config']['params']['query'] = ARGUMENTS.query;
			if ( StructKeyExists(ARGUMENTS,'section') ) LOCAL['config']['params']['section'] = ARGUMENTS.section;
			if ( StructKeyExists(ARGUMENTS,'intent') ) LOCAL['config']['params']['intent'] = ARGUMENTS.intent;
			if ( StructKeyExists(ARGUMENTS,'categoryId') ) LOCAL['config']['params']['categoryId'] = ARGUMENTS.categoryId;
			if ( StructKeyExists(ARGUMENTS,'url') ) LOCAL['config']['params']['url'] = ARGUMENTS.url;
			if ( StructKeyExists(ARGUMENTS,'providerId') ) LOCAL['config']['params']['providerId'] = ARGUMENTS.providerId;
			if ( StructKeyExists(ARGUMENTS,'linkedId') ) LOCAL['config']['params']['linkedId'] = ARGUMENTS.linkedId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="trending" description="Returns a list of venues near the current location with the most people currently checked in" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="ll" type="string" required="true" hint="Latitude and longitude of the user's location, so response can include distance">
		<cfargument name="limit" type="string" required="false" hint="Number of results to return, max of 50">
		<cfargument name="radius" type="numeric" required="false" hint="Radius to search within, in meters">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/trending';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'radius') ) LOCAL['config']['params']['radius'] = ARGUMENTS.radius;
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<!---
		##	 VENUE ASPECTS METHODS ##
	--->
	<cffunction name="herenow" description="Provides a count of how many people are at a given venue. If the request is user authenticated, also returns a list of the users there, friends-first" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 500.">
		<cfargument name="offset" type="numeric" required="false" hint="Used to page through results.">
		<cfargument name="afterTimestamp" type="numeric" required="false" hint="Retrieve the first results to follow these seconds since epoch.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/herenow';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
			if ( StructKeyExists(ARGUMENTS,'afterTimestamp') ) LOCAL['config']['params']['afterTimestamp'] = ARGUMENTS.afterTimestamp;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="venueTips" description="Returns tips for a venue" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="sort" type="string" required="false" hint="One of 'recent' or 'popular'.">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 500.">
		<cfargument name="offset" type="numeric" required="false" hint="Used to page through results.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/tips';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'sort') ) {
				if ( NOT ListFindNoCase('recent,popular',ARGUMENTS.sort) ) {
					// if nearby is specified, then lat and long are required
					 return pkgStruct('', 0, 'Sort must be either "recent", or "popular".');
				} else {
					LOCAL['config']['params']['sort'] = ARGUMENTS.sort;
				}
			}
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="photos" description="Returns tips for a venue" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="group" type="string" required="true" hint="Pass 'checkin' for photos added by friends (including on their recent checkins). Pass 'venue' for public photos added to the venue by non-friends.">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 500.">
		<cfargument name="offset" type="numeric" required="false" hint="Used to page through results.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/photos';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'group') ) {
				if ( NOT ListFindNoCase('checkin,venue',ARGUMENTS.group) ) {
					// if nearby is specified, then lat and long are required
					 return pkgStruct('', 0, 'Group must be either "checkin", or "venue".');
				} else {
					LOCAL['config']['params']['group'] = ARGUMENTS.group;
				}
			}
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="links" description="Returns URLs or identifiers from third parties that have been applied to this venue" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/links';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<!---
		##	 VENUE ACTION METHODS ##
	--->
	<cffunction name="marktodoVenue" description="Allows you to mark a venue to-do, with optional text" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="text" type="string" required="false" hint="The text of the tip.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/marktodo';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'text') ) LOCAL['config']['params']['text'] = ARGUMENTS.text;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="flag" description="Allows users to indicate a venue is incorrect in some way" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">
		<cfargument name="problem" type="string" required="true" hint="Either 'mislocated', 'closed', or 'duplicate'.">
		<cfargument name="venueId" type="string" required="false" hint="ID of the duplicated venue (if problem is 'duplicate')">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/flag';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( ListFindNoCase('mislocated,closed,duplicate',ARGUMENTS.problem)) {
				// then problem must be a specific string
				return pkgStruct('', 0, 'Section must be either "mislocated", "closed", or "duplicate"');
			} else {
				LOCAL['config']['params']['problem'] = ARGUMENTS.problem;
			}
			if ( ARGUMENTS.problem IS 'duplicate' ) LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="editVenue" description="Allows you to make changes to a venue (acting user must be a superuser or venue manager)" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="The venue id to edit">
		<cfargument name="name" type="string" required="false">
		<cfargument name="address" type="string" required="false" hint="The address of the venue">
		<cfargument name="crossStreet" type="string" required="false" hint="The nearest intersecting street or streets">
		<cfargument name="city" type="string" required="false" hint="The city name where this venue is">
		<cfargument name="state" type="string" required="false" hint="The nearest state or province to the venue">
		<cfargument name="zip" type="string" required="false" hint="The zip or postal code for the venue">
		<cfargument name="phone" type="string" required="false" hint="The phone number of the venue">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the venue, as accurate as is known">
		<cfargument name="categoryId" type="string" required="false" hint="The ID of the category to which you want to assign this venue">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/edit';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'name') ) LOCAL['config']['params']['name'] = ARGUMENTS.name;
			if ( StructKeyExists(ARGUMENTS,'address') ) LOCAL['config']['params']['address'] = ARGUMENTS.address;
			if ( StructKeyExists(ARGUMENTS,'crossStreet') ) LOCAL['config']['params']['crossStreet'] = ARGUMENTS.crossStreet;
			if ( StructKeyExists(ARGUMENTS,'city') ) LOCAL['config']['params']['city'] = ARGUMENTS.city;
			if ( StructKeyExists(ARGUMENTS,'state') ) LOCAL['config']['params']['state'] = ARGUMENTS.state;
			if ( StructKeyExists(ARGUMENTS,'zip') ) LOCAL['config']['params']['zip'] = ARGUMENTS.zip;
			if ( StructKeyExists(ARGUMENTS,'phone') ) LOCAL['config']['params']['phone'] = ARGUMENTS.phone;
			if ( StructKeyExists(ARGUMENTS,'ll') ) LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'categoryId') ) LOCAL['config']['params']['categoryId'] = ARGUMENTS.categoryId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="proposeEdit" description="Allows you to propose a change to a venue" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venue_id" type="string" required="true" hint="The venue id to edit">
		<cfargument name="name" type="string" required="false">
		<cfargument name="address" type="string" required="false" hint="The address of the venue">
		<cfargument name="crossStreet" type="string" required="false" hint="The nearest intersecting street or streets">
		<cfargument name="city" type="string" required="false" hint="The city name where this venue is">
		<cfargument name="state" type="string" required="false" hint="The nearest state or province to the venue">
		<cfargument name="zip" type="string" required="false" hint="The zip or postal code for the venue">
		<cfargument name="phone" type="string" required="false" hint="The phone number of the venue">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the venue, as accurate as is known">
		<cfargument name="primaryCategoryId" type="string" required="false" hint="The ID of the category to which you want to assign this venue">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/' & ARGUMENTS.venue_id & '/proposeedit';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'name') ) LOCAL['config']['params']['name'] = ARGUMENTS.name;
			if ( StructKeyExists(ARGUMENTS,'address') ) LOCAL['config']['params']['address'] = ARGUMENTS.address;
			if ( StructKeyExists(ARGUMENTS,'crossStreet') ) LOCAL['config']['params']['crossStreet'] = ARGUMENTS.crossStreet;
			if ( StructKeyExists(ARGUMENTS,'city') ) LOCAL['config']['params']['city'] = ARGUMENTS.city;
			if ( StructKeyExists(ARGUMENTS,'state') ) LOCAL['config']['params']['state'] = ARGUMENTS.state;
			if ( StructKeyExists(ARGUMENTS,'zip') ) LOCAL['config']['params']['zip'] = ARGUMENTS.zip;
			if ( StructKeyExists(ARGUMENTS,'phone') ) LOCAL['config']['params']['phone'] = ARGUMENTS.phone;
			if ( StructKeyExists(ARGUMENTS,'ll') ) LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'primaryCategoryId') ) LOCAL['config']['params']['primaryCategoryId'] = ARGUMENTS.primaryCategoryId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 CHECKINS METHODS ###########################################
		################################################################
	--->
	<cffunction name="checkinDetails" description="Get details of a checkin" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="checkin_id" type="string" required="true" hint="The ID of the checkin to retrieve additional information for.">
		<cfargument name="signature" type="string" required="false" hint="When checkins are sent to public feeds such as Twitter, foursquare appends a signature (s=XXXXXX) allowing users to bypass the friends-only access check on checkins. The same value can be used here for programmatic access to otherwise inaccessible checkins. Callers should use the bit.ly API to first expand 4sq.com links.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/checkins/' & ARGUMENTS.checkin_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'signature') ) LOCAL['config']['params']['signature'] = ARGUMENTS.signature;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="checkin" description="Allows you to check in to a place." returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="broadcast" type="string" required="false" default="public" hint="How much to broadcast this check-in, ranging from private (off-the-grid) to public,facebook,twitter. Can also be just public or public,facebook, for example. If no valid value is found, the default is public. Shouts cannot be private.">
		<cfargument name="venueId" type="string" required="false" hint="The venue where the user is checking in. No venueid is needed if shouting or just providing a venue name. Find venue IDs by searching or from historical APIs.">
		<cfargument name="venue" type="string" required="false" hint="If are not shouting, but you don't have a venue ID or would rather prefer a 'venueless' checkin, pass the venue name as a string using this parameter. It will become an 'orphan' (no address or venueid but with geolat, geolong).">
		<cfargument name="shout" type="string" required="false" hint="A message about your check-in. The maximum length of this field is 140 characters.">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the user's location. Only specify this field if you have a GPS or other device reported location for the user at the time of check-in.">
		<cfargument name="llAcc" type="numeric" required="false" hint="Accuracy of the user's latitude and longitude, in meters">
		<cfargument name="alt" type="numeric" required="false" hint="Altitude of the user's location, in meters">
		<cfargument name="altAcc" type="numeric" required="false" hint="Vertical accuracy of the user's location, in meters.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/checkins/add';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'broadcast') ) LOCAL['config']['params']['broadcast'] = ARGUMENTS.broadcast;
			if ( StructKeyExists(ARGUMENTS,'venueId') ) LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
			if ( StructKeyExists(ARGUMENTS,'venue') ) LOCAL['config']['params']['venue'] = ARGUMENTS.venue;
			if ( StructKeyExists(ARGUMENTS,'shout') ) LOCAL['config']['params']['shout'] = ARGUMENTS.shout;
			if ( StructKeyExists(ARGUMENTS,'ll') ) LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'llAcc') ) LOCAL['config']['params']['llAcc'] = ARGUMENTS.llAcc;
			if ( StructKeyExists(ARGUMENTS,'alt') ) LOCAL['config']['params']['alt'] = ARGUMENTS.alt;
			if ( StructKeyExists(ARGUMENTS,'altAcc') ) LOCAL['config']['params']['altAcc'] = ARGUMENTS.altAcc;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="recent" description="Returns a list of recent checkins from friends" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the user's location, so response can include distance.">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 100.">
		<cfargument name="afterTimestamp" type="numeric" required="false" hint="Seconds after which to look for checkins, e.g. for looking for new checkins since the last fetch. If more than limit results are new since then, this is ignored. Checkins created prior to this timestamp will still be returned if they have new comments or photos, making it easier to poll for all new activity.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/checkins/recent';

			// variables required by this method
			LOCAL['config']['params'] = {};
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
			if ( StructKeyExists(ARGUMENTS,'afterTimestamp') ) LOCAL['config']['params']['afterTimestamp'] = ARGUMENTS.afterTimestamp;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<!---
		##	 CHECKINS ACTION METHODS ##
	--->
	<cffunction name="addComment" description="Comment on a checkin-in" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="checkin_id" type="string" required="false" hint="The ID of the checkin to add a comment to.">
		<cfargument name="text" type="string" required="false" hint="The text of the comment, up to 200 characters">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/checkins/' & ARGUMENTS.checkin_id & '/addcomment';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['text'] = ARGUMENTS.text;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="deleteComment" description="Remove a comment from a checkin-in" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="checkin_id" type="string" required="false" hint="The ID of the checkin to remove a comment from.">
		<cfargument name="commentId" type="string" required="false" hint="The id of the comment to remove">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/checkins/' & ARGUMENTS.checkin_id & '/deletecomment';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['commentId'] = ARGUMENTS.commentId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 TIPS METHODS ###########################################
		################################################################
	--->
	<cffunction name="tip" description="Gives details about a tip, including which users (especially friends) have marked the tip to-do or done" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="tip_id" type="string" required="true" hint="Pass 'self' to get details of the acting user.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tips/' & ARGUMENTS.tip_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="addTip" description="Allows you to add a new tip at a venue" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="venueId" type="string" required="true" hint="The venue where you want to add this tip.">
		<cfargument name="text" type="string" required="true" hint="The text of the tip">
		<cfargument name="url" type="string" required="false" hint="A URL related to this tip.">
		<cfargument name="broadcast" type="string" required="false" hint="Whether to broadcast this tip. Send twitter if you want to send to twitter, facebook if you want to send to facebook, or twitter,facebook if you want to send to both.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tips/add';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
			LOCAL['config']['params']['text'] = ARGUMENTS.text;
			if ( StructKeyExists(ARGUMENTS,'url') ) LOCAL['config']['params']['url'] = ARGUMENTS.url;
			if ( StructKeyExists(ARGUMENTS,'broadcast') ) {
				if (NOT ListFindNoCase('twitter,facebook',ARGUMENTS.broadcast) ) {
					return pkgStruct('', 0, 'Broadcast must be either "twitter", "facebook" or "twitter,facebook" ');
				} else {
					LOCAL['config']['params']['broadcast'] = ARGUMENTS.broadcast;
				}
			}
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="searchTips" description="Returns a list of tips near the area specified" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="ll" type="string" required="true" hint="Latitude and longitude of the user's location">
		<cfargument name="limit" type="numeric" required="false" hint="Number of results to return, up to 500">
		<cfargument name="offset" type="numeric" required="false" hint="Used to page through results">
		<cfargument name="filter" type="string" required="false" hint="If set to 'friends', only show nearby tips from friends">
		<cfargument name="query" type="string" required="false" hint="Only find tips matching the given term, cannot be used in conjunction with friends filter">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/venues/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'limit') ) LOCAL['config']['params']['limit'] = ARGUMENTS.limit;
			if ( StructKeyExists(ARGUMENTS,'offset') ) LOCAL['config']['params']['offset'] = ARGUMENTS.offset;
			if ( StructKeyExists(ARGUMENTS,'filter') ) LOCAL['config']['params']['filter'] = ARGUMENTS.filter;
			if ( StructKeyExists(ARGUMENTS,'query') ) LOCAL['config']['params']['query'] = ARGUMENTS.query;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<!---
		##	 TIPS ACTION METHODS ##
	--->
	<cffunction name="marktodoTip" description="Allows you to mark a tip to-do" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="tip_id" type="string" required="true" hint="The tip you want to mark to-do.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tips/' & ARGUMENTS.tip_id & '/marktodo';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="markdoneTip" description="Allows the acting user to mark a tip done" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="tip_id" type="string" required="true" hint="The tip you want to mark as done.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tips/' & ARGUMENTS.tip_id & '/markdone';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="unmarkTip" description="Allows you to remove a tip from your to-do list or done list" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="tip_id" type="string" required="true" hint="The tip you want to unmark.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/tips/' & ARGUMENTS.tip_id & '/unmark';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 PHOTO METHODS ###########################################
		################################################################
	--->
	<cffunction name="photo" description="Get details of a photo" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="photo_id" type="string" required="true" hint="The ID of the photo to retrieve additional information for.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/photos/' & ARGUMENTS.photo_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="addPhoto" description="Allows users to add a new photo to a checkin, tip, or a venue in general" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="checkinId" type="string" required="false" hint="the ID of a checkin owned by the user.">
		<cfargument name="tipId" type="string" required="false" hint="the ID of a tip owned by the user.">
		<cfargument name="venueId" type="string" required="false" hint="the ID of a venue, provided only when adding a public photo of the venue in general.">
		<cfargument name="broadcast" type="string" required="false" hint="Whether to broadcast this photo. Send twitter if you want to send to twitter, facebook if you want to send to facebook, or twitter,facebook if you want to send to both.">
		<cfargument name="public" type="boolean" required="false" default="1" hint="When the checkinId is also provided (meaning this is a photo attached to a checkin), this parameter allows for making the photo public and viewable at the venue.">
		<cfargument name="ll" type="string" required="false" hint="Latitude and longitude of the user's location.">
		<cfargument name="llAcc" type="numeric" required="false" hint="Accuracy of the user's latitude and longitude, in meters.">
		<cfargument name="alt" type="numeric" required="false" hint="Altitude of the user's location, in meters.">
		<cfargument name="altAcc" type="numeric" required="false" hint="Vertical accuracy of the user's location, in meters.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/photos/' & ARGUMENTS.photo_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
			return pkgStruct('', 0, 'This method is not currently supported.');

			if ( NOT StructKeyExists(ARGUMENTS,'checkinId') AND NOT StructKeyExists(ARGUMENTS,'tipId') AND NOT StructKeyExists(ARGUMENTS,'venueId') ) {
				return pkgStruct('', 0, 'One of checkinId, tipId or venueId must be provided.');
			}
			if ( StructKeyExists(ARGUMENTS,'checkinId') ) LOCAL['config']['params']['checkinId'] = ARGUMENTS.checkinId;
			if ( StructKeyExists(ARGUMENTS,'tipId') ) LOCAL['config']['params']['tipId'] = ARGUMENTS.tipId;
			if ( StructKeyExists(ARGUMENTS,'venueId') ) LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
			if ( StructKeyExists(ARGUMENTS,'broadcast') ) {
				if (NOT ListFindNoCase('twitter,facebook',ARGUMENTS.broadcast) ) {
					return pkgStruct('', 0, 'Broadcast must be either "twitter", "facebook" or "twitter,facebook" ');
				} else {
					LOCAL['config']['params']['broadcast'] = ARGUMENTS.broadcast;
				}
			}
			if ( StructKeyExists(ARGUMENTS,'public') ) LOCAL['config']['params']['public'] = ARGUMENTS.public;
			if ( StructKeyExists(ARGUMENTS,'ll') ) LOCAL['config']['params']['ll'] = ARGUMENTS.ll;
			if ( StructKeyExists(ARGUMENTS,'llAcc') ) LOCAL['config']['params']['llAcc'] = ARGUMENTS.llAcc;
			if ( StructKeyExists(ARGUMENTS,'alt') ) LOCAL['config']['params']['alt'] = ARGUMENTS.alt;
			if ( StructKeyExists(ARGUMENTS,'altAcc') ) LOCAL['config']['params']['altAcc'] = ARGUMENTS.altAcc;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 SETTINGS METHODS ###########################################
		################################################################
	--->
	<cffunction name="settings" description="Returns a setting for the acting user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="setting_id" type="string" required="false" hint="The name of a setting. Leave off to get all settings.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/settings/all';

			// variables required by this method
			LOCAL['config']['params'] = {};
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="settingsChange" description="Returns a setting for the acting user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="setting_id" type="string" required="true" hint="The name of a setting to change.">
		<cfargument name="value" type="boolean" required="true" hint="The value of the setting.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/settings/' & ARGUMENTS.setting_id & '/set';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['value'] = ARGUMENTS.value;
			if ( NOT ListFindNoCase('sendToTwitter, sendMayorshipsToTwitter, sendBadgesToTwitter, sendToFacebook, sendMayorshipsToFacebook, sendBadgesToFacebook, receivePings, receiveCommentPings',ARGUMENTS.setting_id) ) {
				return pkgStruct('', 0, 'Not a valid setting_id');
			} else {
				LOCAL['config']['params']['setting_id'] = ARGUMENTS.setting_id;
			}
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>





	<!---
		################################################################
		##	 SPECIALS METHODS ###########################################
		################################################################
	--->
	<cffunction name="special" description="Gives details about a special, including text and whether it is unlocked for the current user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="special_id" type="string" required="true" hint="ID of special to retrieve.">
		<cfargument name="venueId" type="string" required="true" hint="ID of a venue the special is running at.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/specials/' & ARGUMENTS.special_id;

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="searchSpecials" description="Gives details about a special, including text and whether it is unlocked for the current user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="ll" type="string" required="true" hint="Latitude and longitude of the user's location.">
		<cfargument name="llAcc" type="numeric" required="false" hint="Accuracy of the user's latitude and longitude, in meters.">
		<cfargument name="alt" type="numeric" required="false" hint="Altitude of the user's location, in meters.">
		<cfargument name="altAcc" type="numeric" required="false" hint="Vertical accuracy of the user's location, in meters.">
		<cfargument name="limit" type="string" required="true" hint="Number of results to return, up to 50.">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'GET';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/specials/search';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>

	<cffunction name="flagSpecial" description="Gives details about a special, including text and whether it is unlocked for the current user" returntype="struct" access="public" output="false">
		<cfargument name="outputType" type="string" required="true" default="xml">
		<cfargument name="special_id" type="string" required="true" hint="The id of the special being flagged">
		<cfargument name="venueId" type="string" required="true" hint="The id of the venue running the special">
		<cfargument name="problem" type="string" required="true" hint=" One of not_redeemable, not_valuable, other">
		<cfargument name="text" type="string" required="false" hint="Additional text about why the user has flagged this special">

		<cfscript>
			var LOCAL = {};
			LOCAL['config'] = {};
			LOCAL['returnStruct'] = {};

			// prep packet required by the main call method
			// the following values are required for EVERY call
			LOCAL['config']['method'] = 'POST';
			LOCAL['config']['format'] = ARGUMENTS['outputType'];
			LOCAL['config']['url'] = VARIABLES.baseURL & '/specials/' & ARGUMENTS.special_id & '/flag';

			// variables required by this method
			LOCAL['config']['params'] = {};
			LOCAL['config']['params']['venueId'] = ARGUMENTS.venueId;
			if (NOT ListFindNoCase('not_redeemable,not_valuable,other',ARGUMENTS.problem) ) {
				return pkgStruct('', 0, 'Problem must be either "not_redeemable", "not_valuable" or "other" ');
			} else {
				LOCAL['config']['params']['problem'] = ARGUMENTS.problem;
			}
			if ( StructKeyExists(ARGUMENTS,'text') ) LOCAL['config']['params']['text'] = ARGUMENTS.text;
		</cfscript>

		<cfreturn prep(LOCAL['config'])>
	</cffunction>




</cfcomponent>