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
-module(ets).

%% Interface to the Term store BIF's
%% ets == Erlang Term Store

-export([delete/1,
	 file2tab/1,
	 filter/3,
	 info/1,
	 info/2,
	 match_object/2,
	 safe_fixtable/2,
	 tab2file/2,
	 tab2list/1]).

-export([i/0, i/1, i/2, i/3]).

%% The following functions used to be found in this module, but
%% are now BIFs (i.e. implemented in C).
%%
%% all/0
%% new/2
%% delete/2
%% first/1
%% fixtable/2
%% lookup/2
%% lookup_element/3
%% insert/2
%% last/1
%% next/2
%% prev/2
%% rename/2
%% slot/2
%% match/2
%% match_delete/2
%% update_counter/3
%%

delete(T) when atom(T) ->
    Ret = ets:db_delete(T),
    fixtable_server:table_closed(?MODULE, T),
    Ret;
delete(T) when integer(T) ->
    Ret = ets:db_delete(T),
    fixtable_server:table_closed(?MODULE, T),
    Ret.

safe_fixtable(T, How) when atom(T) -> 
    check_fixtable_access(T, How),
    fixtable_server:safe_fixtable(?MODULE, T, How);
safe_fixtable(T, How) when integer(T) -> 
    check_fixtable_access(T, How),
    fixtable_server:safe_fixtable(?MODULE, T, How).

match_object(T,Pattern) when atom(T) ->
    erlang_db_match_object(T,Pattern);
match_object(T,Pattern) when integer(T) ->
    erlang_db_match_object(T,Pattern).

erlang_db_match_object(Tab, Pat) ->
    erlang_db_match_object(Tab, Pat, 1000).

erlang_db_match_object(Tab, Pat, State0) ->
    case ets:db_match_object(Tab, Pat, State0) of 
	%% a "yield" is done in the BIF if necessary
        State when tuple(State) ->
	    erlang_db_match_object(Tab, Pat, State);
        Result when list(Result) ->
            Result
    end.


info(T) when atom(T) ->
    local_info(T, node());
info(T) when integer(T) ->
    local_info(T, node()).

local_info(T, Node) ->
    case catch ets:db_info(T, memory) of
	undefined -> undefined;
	{'EXIT', _} -> undefined;
	Mem ->
	    {{memory, Mem}, {owner, info(T, owner)}, 
	     {name,info(T, name)},
	     {size, info(T, size)}, {node, Node},
	     {named_table, info(T, named_table)},
	     {type, info(T, type)}, 
	     {keypos, info(T, keypos)},
	     {protection, info(T, protection)}}
    end.

info(T, What) when atom(T) -> 
    local_info(T, What, node());
info(T, What) when integer(T) ->
    local_info(T, What, node()).

local_info(T, What, Node) ->
    case What of 
	node ->
	    Node;
	named_table ->
	    if
		atom(T) -> true;
		true -> false
	    end;
	safe_fixed ->
	    fixtable_server:info(?MODULE, T);
	_ ->
	    case catch ets:db_info(T, What) of
	        undefined -> undefined;
		{'EXIT',_} -> undefined;
		Result -> Result
	    end
    end.

%% Produce a list of {Key,Value} tuples from a table

tab2list(T) ->
    ets:match_object(T, '_').

filter(Tn, F, A) when atom(Tn) ->
    do_filter(Tn,ets:first(Tn),F,A, []);
filter(Tn, F, A) when integer(Tn) ->
    do_filter(Tn,ets:first(Tn),F,A, []).

do_filter(Tab, '$end_of_table', _,_, Ack) -> 
    Ack;
do_filter(Tab, Key, F, A, Ack) ->
    case apply(F, [ets:lookup(Tab, Key) | A]) of
	false ->
	    do_filter(Tab, ets:next(Tab, Key), F,A,Ack);
	true ->
	    Ack2 = lists:append(ets:lookup(Tab, Key), Ack),
	    do_filter(Tab, ets:next(Tab, Key), F,A,Ack2);
	{true, Value} ->
	    do_filter(Tab, ets:next(Tab, Key), F,A,[Value | Ack])
    end.

    
%% Dump a table to a file using the disk_log facility
tab2file(Tab, File) ->
    file:delete(File),
    Name = make_ref(),
    case {disk_log:open([{name, Name}, {file, File}]),
	  local_info(Tab, node())} of
	{{ok, Name}, undefined} ->
	    disk_log:close(Name),
	    {error, badtab};
	{_, undefined} ->
	    {error, badtab};
	{{ok, Name}, Info} ->
	    ok = disk_log:log(Name, Info),
	    tab2file(Tab, ets:first(Tab), Name)
    end.
tab2file(Tab, K, Name) ->
    case get_objs(Tab, K, 10, []) of
	{'$end_of_table', Objs} ->
	    disk_log:log_terms(Name, Objs),
	    disk_log:close(Name);
	{Next, Objs} ->
	    disk_log:log_terms(Name, Objs),
	    tab2file(Tab, Next, Name)
    end.

get_objs(Tab, K, 0, Ack) ->
    {K, lists:reverse(Ack)};
get_objs(Tab, '$end_of_table', _, Ack) ->
    {'$end_of_table', lists:reverse(Ack)};
get_objs(Tab, K, I, Ack) ->
    Os = ets:lookup(Tab, K),
    get_objs(Tab, ets:next(Tab, K), I-1, Os ++ Ack).

%% Restore a table from a file, given that the file was written with
%% the tab2file/2 function from above

file2tab(File) ->
    Name  = make_ref(),
    case disk_log:open([{name, Name}, {file, File}, {mode, read_only}]) of
	{ok, Name} ->
	    init_file2tab(Name);
	{repaired, Name, _,_} ->
	    init_file2tab(Name);
	Other ->
	    old_file2tab(File)  %% compatibilty
    end.

init_file2tab(Name) ->
    case disk_log:chunk(Name, start) of
	{error, Reason} ->
	    file2tab_error(Name, Reason);
	eof ->
	    file2tab_error(Name, eof);
	{Cont, [Info | Tail]} ->
	    case catch mk_tab(tuple_to_list(Info)) of
		{'EXIT', _} ->
		    file2tab_error(Name, "Can't create table");
		Tab ->
		    fill_tab(Cont, Name, Tab, Tail),
		    disk_log:close(Name),
		    {ok, Tab}
	    end
    end.

fill_tab(C, Name, Tab, [H|T]) ->
    ets:insert(Tab, H),
    fill_tab(C, Name, Tab, T);
fill_tab(C, Name, Tab, []) ->
    case disk_log:chunk(Name, C) of
	{error, Reason} ->
	    ets:db_delete(Tab),
	    file2tab_error(Name, Reason);
	eof ->
	    ok;
	{C2, Objs} ->
	    fill_tab(C2, Name, Tab, Objs)
    end.

file2tab_error(Name, Reason) ->
    disk_log:close(Name),
    {error, Reason}.

old_file2tab(File) ->
    case file:read_file(File) of
	{ok, Bin} ->
	    case catch binary_to_term(Bin) of
		{'EXIT',_} -> 
		    {error, badfile};
		{I,S} ->
		    {Tab, Pid} = mk_tab(tuple_to_list(I)),
		    insert_all(Tab, S),
		    {ok,{Tab, Pid}}
	    end;
	_ ->
	    {error, nofile}
    end.

mk_tab(I) ->
    {value, {name, Name}} = lists:keysearch(name, 1, I),
    {value, {type, Type}} = lists:keysearch(type, 1, I),
    {value, {protection, P}} = lists:keysearch(protection, 1, I),
    {value, {named_table, Val}} = lists:keysearch(named_table, 1, I),
    {value, {keypos, Kp}} = lists:keysearch(keypos, 1, I),
    ets:new(Name, [Type, P, {keypos, Kp} | named_table(Val)]).

named_table(true) -> [named_table];
named_table(false) -> [].

insert_all(Tab, [Val|T]) ->
    ets:insert(Tab, Val),
    insert_all(Tab,T);
insert_all(Tab,[]) -> Tab.


%% Print info about all tabs on the tty
i() ->
    hform('id', 'name', 'type', 'size', 'mem', 'owner'),
    io:format(" -------------------------------------"
	      "---------------------------------------\n"),
    lists:foreach(fun prinfo/1, tabs()),
    ok.

tabs() ->
    lists:sort(ets:all()).

prinfo(Tab) ->
    case catch prinfo2(Tab) of
	{'EXIT', _} ->
	    io:format("~-10s ... unreadable \n", [to_string(Tab)]);
	ok -> 
	    ok
    end.
prinfo2(Tab) ->
    Name = ets:info(Tab, name),
    Type = ets:info(Tab, type),
    Size = ets:info(Tab, size),
    Mem = ets:info(Tab, memory),
    Owner = ets:info(Tab, owner),
    hform(Tab, Name, Type, Size, Mem, is_reg(Owner)).

is_reg(Owner) ->
    case process_info(Owner, registered_name) of
	{registered_name, Name} -> Name;
	_ -> Owner
    end.

%%% Arndt: this code used to truncate over-sized fields. Now it
%%% pushes the remaining entries to the right instead, rather than
%%% losing information.
hform(A0, B0, C0, D0, E0, F0) ->
    [A,B,C,D,E,F] = lists:map(fun to_string/1, [A0,B0,C0,D0,E0,F0]),
    A1 = pad_right(A, 15),
    B1 = pad_right(B, 17),
    C1 = pad_right(C, 5),
    D1 = pad_right(D, 6),
    E1 = pad_right(E, 8),
    %% no need to pad the last entry on the line
    io:format(" ~s ~s ~s ~s ~s ~s\n", [A1,B1,C1,D1,E1,F]).

pad_right(String, Len) ->
    if
	length(String) >= Len ->
	    String;
	true ->
	    [Space] = " ",
	    String ++ lists:duplicate(Len - length(String), Space)
    end.

to_string(X) ->
    lists:flatten(io_lib:format("~p", [X])).

%% view a specific table 
i(Tab) ->
    i(Tab, 40).
i(Tab, Height) ->
    i(Tab, Height, 80).
i(Tab, Height, Width) ->
    First = ets:first(Tab),
    display_items(Height, Width, Tab, First, 1, 1).

display_items(Height, Width, Tab, '$end_of_table', Turn, Opos) -> 
    P = 'EOT  (q)uit (p)Digits (k)ill /Regexp -->',
    choice(Height, Width, P, eot, Tab, '$end_of_table', Turn, Opos);
display_items(Height, Width, Tab, Key, Turn, Opos) when Turn < 0 ->
    i(Tab, Height, Width);
display_items(Height, Width, Tab, Key, Turn, Opos) when Turn < Height ->
    do_display(Height, Width, Tab, Key, Turn, Opos);
display_items(Height, Width, Tab, Key, Turn, Opos) when Turn >=  Height ->
    P = '(c)ontinue (q)uit (p)Digits (k)ill /Regexp -->',
    choice(Height, Width, P, normal, Tab, Key, Turn, Opos).

choice(Height, Width, P, Mode, Tab, Key, Turn, Opos) ->
    case get_line(P, "c\n") of
	"c\n" when Mode == normal ->
	    do_display(Height, Width, Tab, Key, 1, Opos);
	"c\n" when tuple(Mode), element(1, Mode) == re ->
	    {re, Re} = Mode,
	    re_search(Height, Width, Tab, Key, Re, 1, Opos);
	"q\n" ->
	    quit;
	"k\n" ->
	    ets:delete(Tab);
	[$p|Digs]  ->
	    catch case catch list_to_integer(nonl(Digs)) of
		      {'EXIT', _} ->
			  io:format("Bad digits \n", []);
		      Number when Mode == normal ->
			  print_number(Tab, ets:first(Tab), Number);
		      Number when Mode == eot ->
			  print_number(Tab, ets:first(Tab), Number);
		      Number -> %% regexp
			  {re, Re} = Mode,
			  print_re_num(Tab, ets:first(Tab), Number, Re)
		  end,
	    choice(Height, Width, P, Mode, Tab, Key, Turn, Opos);
	[$/|Regexp]   -> %% from regexp
	    re_search(Height, Width, Tab, ets:first(Tab), nonl(Regexp), 1, 1);
	_  ->
	    choice(Height, Width, P, Mode, Tab, Key, Turn, Opos)
    end.

get_line(P, Default) ->
    case io:get_line(P) of
	"\n" ->
	    Default;
	L ->
	    L
    end.

nonl(S) -> string:strip(S, right, $\n).

print_number(Tab, Key, Num) ->
    Os = ets:lookup(Tab, Key),
    Len = length(Os),
    if 
	(Num - Len) < 1 ->
	    O = lists:nth(Num, Os),
	    io:format("~p~n", [O]); %% use ppterm here instead
	true ->
	    print_number(Tab, ets:next(Tab, Key), Num - Len)
    end.

do_display(Height, Width, Tab, Key, Turn, Opos) ->
    Objs = ets:lookup(Tab, Key),
    do_display_items(Height, Width, Objs, Opos),
    Len = length(Objs),
    display_items(Height, Width, Tab, ets:next(Tab, Key), Turn+Len, Opos+Len).

do_display_items(Height, Width, [Obj|Tail], Opos) ->
    do_display_item(Height, Width, Obj, Opos),
    do_display_items(Height, Width, Tail, Opos+1);
do_display_items(Height, Width, [], Opos) ->
    Opos.

do_display_item(Height, Width, I, Opos)  ->
    L = to_string(I),
    L2 = if
	     length(L) > Width - 8 ->
		 lists:append(string:substr(L, 1, Width-13), "  ...");
	     true ->
		 L
	 end,
    io:format("<~-4w> ~s~n", [Opos,L2]).

re_search(Height, Width, Tab, '$end_of_table', Re, Turn, Opos) ->
    P = 'EOT  (q)uit (p)Digits (k)ill /Regexp -->',
    choice(Height, Width, P, {re, Re}, Tab, '$end_of_table', Turn, Opos);

re_search(Height, Width, Tab, Key, Re, Turn, Opos) when Turn < Height ->
    re_display(Height, Width, Tab, Key, ets:lookup(Tab, Key), Re, Turn, Opos);

re_search(Height, Width, Tab, Key, Re, Turn, Opos)  ->
    P = '(c)ontinue (q)uit (p)Digits (k)ill /Regexp -->',
    choice(Height, Width, P, {re, Re}, Tab, Key, Turn, Opos).

re_display(Height, Width, Tab, Key, [], Re, Turn, Opos) ->
    re_search(Height, Width, Tab, ets:next(Tab, Key), Re, Turn, Opos);
re_display(Height, Width, Tab, Key, [H|T], Re, Turn, Opos) ->
    Str = to_string(H),
    case regexp:match(Str, Re) of
	{match,_,_} ->
	    do_display_item(Height, Width, H, Opos),
	    re_display(Height, Width, Tab, Key, T, Re, Turn+1, Opos+1);
	_ ->
	    re_display(Height, Width, Tab, Key, T, Re, Turn, Opos)
    end.

print_re_num(_,'$end_of_table',_,_) -> ok;
print_re_num(Tab, Key, Num, Re) ->
    Os = re_match(ets:lookup(Tab, Key), Re),
    Len = length(Os),
    if 
	(Num - Len) < 1 ->
	    O = lists:nth(Num, Os),
	    io:format("~p~n", [O]); %% use ppterm here instead
	true ->
	    print_re_num(Tab, ets:next(Tab, Key), Num - Len, Re)
    end.

re_match([], _) -> [];
re_match([H|T], Re) ->
    case regexp:match(to_string(H), Re) of
	{match,_,_} -> 
	    [H|re_match(T,Re)];
	_ ->
	    re_match(T, Re)
    end.

check_fixtable_access(T, B) ->
    Self = self(),
    case ets:db_info(T, owner) of
	Self ->
	    ok;
	_ ->
	    case ets:db_info(T, protection) of
		public ->
		    ok;
		_ ->
		    exit({badarg, {?MODULE, safe_fixtable, [T, B]}})
	    end
    end.