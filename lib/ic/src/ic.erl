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
-module(ic).


-export([sgen/1, gen/1, gen/2, help/0, compile/3]).


%%------------------------------------------------------------
%%
%% Internal stuff
%%
%%------------------------------------------------------------

-export([filter_params/2, handle_preproc/4, do_gen/4]).

-import(icgen, [to_list/1, get_id2/1, 
		push_file/2, pop_file/2, sys_file/2]).


-import(lists, [foldr/3]).


-include("icforms.hrl").
-include("ic.hrl").

-include_lib("stdlib/include/erl_compile.hrl").

-export([make_erl_options/1]).			% For erlc

-export([main/3, do_scan/1, do_parse/2, do_type/2]).


%% Internal
%%-export([call/4,worker/0]).

%%------------------------------------------------------------
%%
%% Entry point
%%
%%------------------------------------------------------------

%% compile(AbsFileName, Outfile, Options)
%%   Compile entry point for erl_compile.

compile(File, _OutFile, Options) ->
    case gen(File, make_erl_options(Options)) of
	ok -> ok;
	Other -> Other
    end.


%% Entry for the -s switch
sgen(ArgList) ->
%%%    io:format("sgen called w ~p~n", [ArgList]),
    apply(?MODULE, gen, ArgList).


gen(File) ->
    gen(File, []).

gen(File, Opts) ->
    G = icgen:new(Opts),
    IdlFile = icgen:add_dot_idl(File),
    case ic_options:get_opt(G, show_opts) of
	true ->
	    io:format("Opts: ~p~n", [icgen:which_opts(G)]);
	_ -> ok
    end,
    icgen:set_idlfile(G, IdlFile),
    case catch gen2(G, File, Opts) of
	{_, {'EXIT', R}} -> 
	    icgen:free_table_space(G), %% Free space for all ETS tables
	    %%exit(R);
	    io:format("Fatal error : ~p~n",[R]),
	    error;
	{_, {'EXIT', _, R}} -> 
	    icgen:free_table_space(G), %% Free space for all ETS tables
	    %%exit(R);
	    io:format("Fatal error : ~p~n",[R]),
	    error;
	{'EXIT', R} -> 
	    icgen:free_table_space(G), %% Free space for all ETS tables
	    %%exit(R);
	    io:format("Fatal error : ~p~n",[R]),
	    error;
	{'EXIT', _, R} -> 
	    icgen:free_table_space(G), %% Free space for all ETS tables
	    %%exit(R);
	    io:format("Fatal error : ~p~n",[R]),
	    error;
	
	%% In this case, the pragma registration 
        %% found errors so this should return error.
	error ->
	    icgen:free_table_space(G), %% Free space for all ETS tables
	    error;
	_ -> 
	    X = icgen:return(G),
	    %io:format("~p~n",[ets:tab2list(icgen:tktab(G))]),
	    %ic_pragma:print_tab(G),
	    %io:format("Options ~p~n",[icgen:which_opts(G)]),
	    icgen:free_table_space(G), %% Free space for all ETS tables
	    X
    end.


gen2(G, File, Opts) ->
    %%    G = icgen:new(Opts),
    %%    IdlFile = icgen:add_dot_idl(File),
    %%    icgen:set_idlfile(G, IdlFile),
    case ic_options:get_opt(G, time) of
	true -> 
	    time("TOTAL                ", ic, main, [G, File, Opts]);
	_ -> 
	    %%    icgen:return(G).
	    case main(G, File, Opts) of
		error ->
		    error;
		_ ->
		    ok
	    end
    end.



do_gen(erl_corba, G, File, T) ->
    ic_erlbe:do_gen(G, File, T);
do_gen(erl_genserv, G, File, T) ->
    ic_erlbe:do_gen(G, File, T);
do_gen(c_genserv, G, File, T) ->
    ic_cbe:do_gen(G, File, T);
do_gen(noc, G, File, T) ->
    ic_noc:do_gen(G, File, T);
do_gen(erl_plain, G, File, T) ->
    ic_plainbe:do_gen(G, File, T);
do_gen(c_server, G, File, T) ->
    ic_cserver:do_gen(G, File, T);
do_gen(c_client, G, File, T) ->
    ic_cbe:do_gen(G, File, T);
%% Java backend
do_gen(java, G, File, T) ->
    ic_jbe:do_gen(G, File, T);
%% No language choice
do_gen(_,_,_,_) -> 
    ok.

do_scan(G) ->
    icscan:scan(G, icgen:idlfile(G)).
    

do_parse(G, Tokens) ->
    case icparse:parse(Tokens) of
	{ok, L} -> L;
	X when element(1, X) == error -> 
	    Err = element(2, X),
	    icgen:fatal_error(G, {parse_error, element(1, Err), 
				  element(3, Err)});
	X -> exit(X)
    end.


do_type(G, Form) ->
    ictype:type_check(G, Form).
	
time(STR,M,F,A) ->
    case timer:tc(M, F, A) of
	{_, {'EXIT', R}} -> exit(R);
	{_, {'EXIT', _, R}} -> exit(R);
	{_, _X} when element(1, _X)==error -> throw(_X);
	{_T, _R} -> 
	    io:format("Time for ~s:  ~10.2f~n", [STR, _T/1000000]),
	    _R
    end.



%% Filters parameters so that only those with certain attributes are
%% seen. The filter parameter is a list of attributes that will be
%% seen, ex. [in] or [inout, out]
filter_params(Filter, Params) ->
    lists:filter(fun(P) ->
		    lists:member(get_param_attr(P#param.inout), Filter) end,
		 Params).


%% Access primitive to get the attribute name (and discard the line
%% number).
get_param_attr({A, N}) -> A.


%%
%% Fixing the preproc directives
%%
handle_preproc(G, N, line_nr, X) ->
    Id = get_id2(X),
    Flags = X#preproc.aux,
    case Flags of
	[] -> push_file(G, Id);
	_ ->
	    foldr(fun({_, _, "1"}, Gprim) -> push_file(Gprim, Id);
		     ({_, _, "2"}, Gprim) -> pop_file(Gprim, Id);
		     ({_, _, "3"}, Gprim) -> sys_file(Gprim, Id) end,
		  G, Flags)
    end;
handle_preproc(G, N, Other, X) ->
    G.



%%------------------------------------------------------------
%%
%% The help department
%%
%% 
%%
%%------------------------------------------------------------

help() ->
    io:format("No help available at the moment~n", []),
    ok.

print_version_str(G) ->
    case {ic_options:get_opt(G, silent), ic_options:get_opt(G, silent2)} of
	{true, _} -> ok;
	{_, true} -> ok;
	_ -> 
	    io:format("Erlang IDL compiler version ~s~n", [?COMPILERVSN])
    end.



%%
%% Converts generic compiler options to specific options.
%% 
%% Used by erlc
%%

make_erl_options(Opts) ->

    %% This way of extracting will work even if the record passed
    %% has more fields than known during compilation.

    Includes0 = Opts#options.includes,
    Defines = Opts#options.defines,
    Outdir = Opts#options.outdir,
    Warning = Opts#options.warning,
    Verbose = Opts#options.verbose,
    Specific = Opts#options.specific,
    Optimize = Opts#options.optimize,
    OutputType = Opts#options.output_type,
    Cwd = Opts#options.cwd,

    Includes1 = 
	case Opts#options.ilroot of
	    undefined ->
		Includes0;
	    Ilroot ->
		[Ilroot|Includes0]
	end,
    PreProc = 
	lists:flatten(
	  lists:map(fun(D) -> io_lib:format("-I~s ", [to_list(D)]) end, 
		    Includes1)++
	  lists:map(
	    fun ({Name, Value}) ->
		    io_lib:format("-D~s=~s ", [to_list(Name), to_list(Value)]);
		(Name) ->
		    io_lib:format("-D~s ", [to_list(Name)])
	    end,
	    Defines)),
    Options =
	case Verbose of
	    true ->  [];
	    false -> []
	end ++
	case Warning of
	    0 -> [nowarn];
	    _ -> ['Wall']
	end ++
	case Optimize of
	    0 -> [];
	    _ -> []
	end,
    
    Options++[{outdir, Outdir}, {preproc_flags, PreProc}]++Specific.





%%%
%%% NEW main, threaded, avoids memory fragmentation
%%%
%main(G, File, Opts) ->
%    print_version_str(G),
%    ?ifopt(G, time, io:format("File ~p compilation started  :   ~p/~p/~p ~p:~2.2.0p~n", 
%			      [ic_genobj:idlfile(G),
%			       element(1,date()),
%			       element(2, date()),
%			       element(3, date()),
%			       element(1, time()),
%			       element(2, time())])),
%    WOpt=[],

%    case ic_options:get_opt(G, help) of
%	true -> help();

%	_ ->
%	    scaning(G, File, WOpt)
%    end.



%scaning(G, File, WOpt) ->
%    S = ?ifopt2(G, time,
%	       time("input file scanning  ", ic, call, [ic,do_scan,[G],WOpt]),
%	       call(ic,do_scan,[G],WOpt)),
%    ?ifopt(G, tokens, io:format("TOKENS: ~p~n", [S])),
%    parsing(G, File, S, WOpt).



%parsing(G, File, S, WOpt) ->
%    T = ?ifopt2(G, 
%		time, 
%		time("input file parsing   ", ic, call, [ic,do_parse,[G,S],WOpt]),
%		call(ic,do_parse,[G,S],WOpt)),
%    ?ifopt(G, form, io:format("PARSE FORM: ~p~n", [T])),
%    pragma(G, File, T, WOpt).



%pragma(G, File, T, WOpt) ->
%    case ?ifopt2(G, 
%		 time,
%		 time("pragma registration  ", ic, call, [ic_pragma,pragma_reg,[G,T],WOpt]),
%		 call(ic_pragma,pragma_reg,[G,T],WOpt)) of
%	%% All pragmas were succesfully applied
%	{ok,Clean} ->
%	    typing(G, File, Clean, WOpt);
	
%	error ->
%	    error
%    end.


%typing(G, File, Clean, WOpt) ->
%    case catch ?ifopt2(G, 
%		       time,
%		       time("type code appliance  ", ic, call, [ic,do_type,[G,Clean],WOpt]),
%		       call(ic,do_type,[G,Clean],WOpt)) of
%	{'EXIT',Reason} ->
%	    io:format("Error under type appliance : ~p~n",[Reason]),
%	    error;
	
%	T2 ->	    
%	    ?ifopt(G, tform, io:format("TYPE FORM: ~p~n", [T2])),
	 
%	    generation(G, File, T2, WOpt)
%    end.


%generation(G, File, T2, WOpt) ->
%    case icgen:get_error_count(G) of
%	0 ->
%	    %% Check if user has sett backend option
%	    case ic_options:get_opt(G, be) of
%		false ->
%		    %% Use default backend option
%		    DefaultBe = icgen:defaultBe(),
%		    icgen:add_opt(G,[{be,DefaultBe}],true),
		 
%		    ?ifopt2(G, 
%			    time,
%			    time("code generation      ", ic, do_gen, [DefaultBe, G, File, T2]),
%			    ic:do_gen(DefaultBe, G, File, T2));
%		Be ->
%		    %% Use user defined backend		    
%		    ?ifopt2(G, 
%			    time,
%			    time("code generation      ", ic, do_gen, [Be, G, File, T2]),
%			    ic:do_gen(Be, G, File, T2))
%	    end;
%	_ ->
%	    ok	    %% Does not matter
%    end.
	


%call(Mod,Fun,Args,Opts) ->
%    Pid = spawn_opt(ic,worker,[],Opts),
%    Pid ! {self(),{call, Mod, Fun, Args}},
%    receive 
%	{reply, {'EXIT',Reason}} ->
%	    throw({'EXIT',Reason});
%	{reply, OutPut} ->
%	    OutPut
%    end.

%worker() ->
%    receive
%	{Pid,{call, Mod, Fun, Args}} ->
%	    %%io:format("Calling ~p \n",[Fun]),
%	    Pid ! {reply, catch apply(Mod,Fun,Args)}
%	    %%io:format("Finished with ~p \n",[Fun])
%    end.







%%%
%%% NEW main, avoids memory fragmentation
%%%
main(G, File, Opts) ->
    print_version_str(G),
    ?ifopt(G, time, io:format("File ~p compilation started  :   ~p/~p/~p ~p:~2.2.0p~n", 
			      [ic_genobj:idlfile(G),
			       element(1,date()),
			       element(2, date()),
			       element(3, date()),
			       element(1, time()),
			       element(2, time())])),

    case ic_options:get_opt(G, help) of
	true -> help();

	_ ->
	    scaning(G, File)
    end.



scaning(G, File) ->
    S = ?ifopt2(G, time,
	       time("input file scanning  ", ic, do_scan, [G]),
	       ic:do_scan(G)),
    ?ifopt(G, tokens, io:format("TOKENS: ~p~n", [S])),
    parsing(G, File, S).



parsing(G, File, S) ->
    T = ?ifopt2(G, 
		time, 
		time("input file parsing   ", ic, do_parse, [G,S]),
		ic:do_parse(G,S)),
    ?ifopt(G, form, io:format("PARSE FORM: ~p~n", [T])),
    pragma(G, File, T).



pragma(G, File, T) ->
    case ?ifopt2(G, 
		 time,
		 time("pragma registration  ", ic_pragma, pragma_reg, [G,T]),
		 ic_pragma:pragma_reg(G,T)) of
	%% All pragmas were succesfully applied
	{ok,Clean} ->
	    typing(G, File, Clean);
       
	error ->
	    error
    end.


typing(G, File, Clean) ->
    case catch ?ifopt2(G, 
		       time,
		       time("type code appliance  ", ic, do_type, [G,Clean]),
		       ic:do_type(G,Clean)) of
	{'EXIT',Reason} ->
	    io:format("Error under type appliance : ~p~n",[Reason]),
	    error;
       
	T2 ->	    
	    ?ifopt(G, tform, io:format("TYPE FORM: ~p~n", [T2])),
        
	    generation(G, File, T2)
    end.


generation(G, File, T2) ->
    case icgen:get_error_count(G) of
	0 ->
	    %% Check if user has sett backend option
	    case ic_options:get_opt(G, be) of
		false ->
		    %% Use default backend option
		    DefaultBe = icgen:defaultBe(),
		    icgen:add_opt(G,[{be,DefaultBe}],true),
		    
		    ?ifopt2(G, 
			    time,
			    time("code generation      ", ic, do_gen, [DefaultBe, G, File, T2]),
			    ic:do_gen(DefaultBe, G, File, T2));
		Be ->
		    %% Use user defined backend		    
		    ?ifopt2(G, 
			    time,
			    time("code generation      ", ic, do_gen, [Be, G, File, T2]),
			    ic:do_gen(Be, G, File, T2))
	    end;
	_ ->
	    ok	    %% Does not matter
    end.
	

