%%--------------------------------------------------------------------
%% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% The Initial Developer of the Original Code is Ericsson Utvecklings AB.
%% Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
%% AB. All Rights Reserved.''
%% 
%%     $Id$
%%
%%----------------------------------------------------------------------
%% File    : CosNotifyFilter_FilterFactory_impl.erl
%% Purpose : 
%% Created : 29 Dec 1999
%%----------------------------------------------------------------------

-module('CosNotifyFilter_FilterFactory_impl').


%%--------------- INCLUDES -----------------------------------
%% Application files
-include_lib("orber/include/corba.hrl").
-include_lib("orber/include/ifr_types.hrl").
%% Application files
-include("CosNotification.hrl").
-include("CosNotifyChannelAdmin.hrl").
-include("CosNotifyComm.hrl").
-include("CosNotifyFilter.hrl").
-include("CosNotification_Definitions.hrl").

%%--------------- IMPORTS ------------------------------------

%%--------------- EXPORTS ------------------------------------
%% External
-export([create_filter/3,
	 create_mapping_filter/4]).

%%--------------- gen_server specific exports ----------------
-export([handle_info/2, code_change/3]).
-export([init/1, terminate/2]).

%%--------------- LOCAL DEFINITIONS --------------------------
%% Data structures
-record(state, {adminProp,
		etsR}).

%% Data structures constructors
-define(get_InitState(), 
	#state{}).

%% Data structures selectors

%% Data structures modifiers

%%-----------------------------------------------------------%
%% function : handle_info, code_change
%% Arguments: See gen_server documentation.
%% Effect   : Functions demanded by the gen_server module. 
%%------------------------------------------------------------

code_change(OldVsn, State, Extra) ->
    {ok, State}.

handle_info(Info, State) ->
    ?debug_print("INFO: ~p  DATA: ~p~n", [State, Info]),
    {noreply, State}.

%%----------------------------------------------------------%
%% function : init, terminate
%% Arguments: 
%%-----------------------------------------------------------

init(Env) ->
    process_flag(trap_exit, true),
    {ok, ?get_InitState()}.

terminate(Reason, State) ->
    ok.

%%-----------------------------------------------------------
%%------- Exported external functions -----------------------
%%-----------------------------------------------------------
%%----------------------------------------------------------%
%% function : create_filter
%% Arguments: InitGrammar - string()
%% Returns  : CosNotifyFilter::Filter | 
%%            {'EXCEPTION', InvalidGrammar}
%%-----------------------------------------------------------
create_filter(OE_THIS, State, InitGrammar) ->
    case lists:member(InitGrammar, ?not_SupportedGrammars) of
	true ->
	    Fi='CosNotifyFilter_Filter':oe_create_link([OE_THIS, self(), 
							InitGrammar]),
	    {reply, Fi, State};
	_ ->
	    corba:raise(#'CosNotifyFilter_InvalidGrammar'{})
    end.

%%----------------------------------------------------------%
%% function : create_mapping_filter
%% Arguments: InitGrammar - string()
%% Returns  : CosNotifyFilter::Filter | 
%%            {'EXCEPTION', InvalidGrammar}
%%-----------------------------------------------------------
create_mapping_filter(OE_THIS, State, InitGrammar, DefVal) ->
    case lists:member(InitGrammar, ?not_SupportedGrammars) of
	true ->
	    Fi='CosNotifyFilter_MappingFilter':oe_create_link([OE_THIS, self(), 
							       InitGrammar, DefVal]),
	    {reply, Fi, State};
	_ ->
	    corba:raise(#'CosNotifyFilter_InvalidGrammar'{})
    end.

%%--------------- LOCAL FUNCTIONS ----------------------------
%%--------------- MISC FUNCTIONS, E.G. DEBUGGING -------------
%%--------------- END OF MODULE ------------------------------