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
%%-----------------------------------------------------------------
%% File    : OrberApp_IFR_impl.erl
%% Purpose : 
%% Created :  3 Nov 1999
%%-----------------------------------------------------------------

-module('OrberApp_IFR_impl').

%%--------------- INCLUDES -----------------------------------
-include_lib("orber/src/orber_iiop.hrl").
-include_lib("orber/include/ifr_types.hrl").
-include_lib("orber/include/corba.hrl").
-include_lib("orber/src/orber_debug.hrl").

%%--------------- IMPORTS ------------------------------------

%%--------------- EXPORTS ------------------------------------
%% External
-export([get_absolute_name/3, get_user_exception_type/3]).

%%--------------- gen_server specific exports ----------------
-export([init/1, terminate/2, code_change/3]).

%%--------------- LOCAL DEFINITIONS --------------------------
-define(DEBUG_LEVEL, 6).


init(State) ->
    {ok, State}.
terminate(Reason, State) ->
    ok.
code_change(OldVsn, State, Extra) ->
    {ok, State}.

%%-----------------------------------------------------------
%%------- Exported external functions -----------------------
%%-----------------------------------------------------------
%%----------------------------------------------------------%
%% function : get_absolute_name
%% Arguments: TypeID - string()
%% Returns  : Fully scooped name - string()
%%-----------------------------------------------------------

get_absolute_name(OE_THIS, State, []) ->
    orber:debug_level_print("[~p] OrberApp_IFR_impl:get_absolute_name(); no TypeID supplied.", 
			    [?LINE], ?DEBUG_LEVEL),
    corba:raise(#'MARSHAL'{minor=107, completion_status=?COMPLETED_MAYBE});

get_absolute_name(OE_THIS, State, TypeID) ->
    Rep = orber_ifr:find_repository(),
    Key = orber_ifr:'Repository_lookup_id'(Rep, TypeID),
    [$:, $: |N] = orber_ifr:'Contained__get_absolute_name'(Key),
    {reply, change_colons_to_underscore(N, []), State}.

change_colons_to_underscore([$:, $: | T], Acc) ->
    change_colons_to_underscore(T, [$_ |Acc]);
change_colons_to_underscore([H |T], Acc) ->
    change_colons_to_underscore(T, [H |Acc]);
change_colons_to_underscore([], Acc) ->
    lists:reverse(Acc).

%%----------------------------------------------------------%
%% function : get_user_exception_type
%% Arguments: TypeID - string()
%% Returns  : Fully scooped name - string()
%%-----------------------------------------------------------

get_user_exception_type(OE_THIS, State, []) -> 
    orber:debug_level_print("[~p] OrberApp_IFR_impl:get_user_exception_type(); no TypeID supplied.", 
			    [?LINE], ?DEBUG_LEVEL),
    corba:raise(#'MARSHAL'{minor=107, completion_status=?COMPLETED_MAYBE});

get_user_exception_type(OE_THIS, State, TypeId) -> 
    Rep = orber_ifr:find_repository(),
    ExceptionDef = orber_ifr:'Repository_lookup_id'(Rep, TypeId),
    ContainedDescr = orber_ifr_exceptiondef:describe(ExceptionDef),
    ExceptionDescr = ContainedDescr#contained_description.value,
    {reply, ExceptionDescr#exceptiondescription.type, State}.


%%--------------- LOCAL FUNCTIONS ----------------------------
%%--------------- MISC FUNCTIONS, E.G. DEBUGGING -------------
%%--------------- END OF MODULE ------------------------------