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
%% File: lname.erl
%% Author: Lars Thorsen
%% 
%% Creation date: 970926
%% Modified:
%%-----------------------------------------------------------------
-module(lname).

-include_lib("orber/include/corba.hrl").
-include("CosNaming.hrl").
-include("lname.hrl").

%%-----------------------------------------------------------------
%% External exports
%%-----------------------------------------------------------------
-export([create/0, insert_component/3, get_component/2, delete_component/2,
	 num_component/1, equal/2, less_than/2,
	 to_idl_form/1, from_idl_form/1, check_name/1, new/1]).

%%-----------------------------------------------------------------
%% Internal exports
%%-----------------------------------------------------------------
-export([]).

%%-----------------------------------------------------------------
%% External interface functions
%%-----------------------------------------------------------------
create() ->
    [].

insert_component(_, I, _) when I < 1->
    corba:raise(#'LName_NoComponent'{});
insert_component([], I, _) when I > 1->
    corba:raise(#'LName_NoComponent'{});
insert_component(Name, 1, Component) when record(Component,
						 'CosNaming_NameComponent') ->
    [Component |Name];
insert_component([H|T], I, Component) when record(Component,
						  'CosNaming_NameComponent') ->
    [H |insert_component(T, I-1, Component)];
insert_component(_, _, Component) -> 
    corba:raise(#'BAD_PARAM'{completion_status=?COMPLETED_NO}).

get_component(_, I) when I < 1->
    corba:raise(#'LName_NoComponent'{});
get_component([], _) ->
    corba:raise(#'LName_NoComponent'{});
get_component([H|T], 1) ->
    H;
get_component([H|T], I) ->
    get_component(T, I-1).

delete_component(_, I) when I < 1->
    corba:raise(#'LName_NoComponent'{});
delete_component([], _) ->
    corba:raise(#'LName_NoComponent'{});
delete_component([H|T], 1) ->
    T;
delete_component([H|T], I) ->
    [H | delete_component(T, I-1)].

num_component(Name) ->
    num_component(Name, 0).

equal(Name, N) ->
    N == Name.

less_than(Name, N) ->
    Name < N.

to_idl_form(Name) ->
    case check_name(Name) of
	false ->
	    corba:raise(#'LName_InvalidName'{});
	true ->
	    Name
    end.

from_idl_form(Name) ->
    Name.
	
%%destroy() -> % not needed in erlang
%%    ok.

%%-----------------------------------------------------------------
%% External Functions not in the CosNaming standard
%%-----------------------------------------------------------------
new([]) ->
    [];
new([{Id, Kind} | List]) ->
    [lname_component:new(Id, Kind) | new(List)];
new([Id |List]) when list(Id) ->
    [lname_component:new(Id) | new(List)].

%%-----------------------------------------------------------------
%% Internal Functions
%%-----------------------------------------------------------------
num_component([], N) ->
    N;
num_component([H|T], N) ->
    num_component(T, N+1).

check_name([]) ->
    true;
check_name([H|T]) ->
    case catch lname_component:get_id(H) of
	{'EXCEPTION', E} ->
	    false;
	_ ->
	    check_name(T)
    end.