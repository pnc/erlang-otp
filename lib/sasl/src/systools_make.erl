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
-module(systools_make).

%% Purpose : Create start script. RelName.rel --> RelName.{script,boot}.
%%           and create a tar file of a release (RelName.tar.gz)

-export([make_script/1, make_script/2, make_script/3,
	 make_tar/1, make_tar/2]).

-export([format_error/1, format_warning/1]).

-export([read_release/2, get_release/2, get_release/3,
	 get_release/4, pack_app/1]).

-import(lists, [filter/2, keysort/2, keysearch/3, map/2, reverse/1,
		append/1, foldl/3,  member/2, foreach/2]).

-include("systools.hrl").

-include_lib("kernel/include/file.hrl").

%%-----------------------------------------------------------------
%% Create a boot script from a release file.
%% Options is a list of {path, Path} | silent | local where path sets
%% the search path, silent supresses error message printing on console,
%% local generates a script with references to the directories there
%% the applications are found.
%%
%% New options: {path,Path} can contain wildcards
%%              no_module_tests
%%              {variables,[{Name,AbsString}]}
%%              {machine, jam | beam | vee}
%%              exref | {exref, [AppName]}
%%-----------------------------------------------------------------

make_script(RelName) when list(RelName) ->
    make_script(RelName, []);
make_script(RelName) ->
    badarg(make_script,RelName,[RelName]).

make_script(RelName, Flags) when list(RelName), list(Flags) ->
    make_script(RelName, RelName, Flags).
    
make_script(RelName, Output, Flags) when list(RelName), list(Output), list(Flags) ->
    case check_args_script(Flags) of
	{R_Path, R_Sil, R_Loc, R_Test, R_Var, R_Mach, R_Xref, R_XrefApps, []} ->
	    Path0 = get_path(Flags),
	    Path = mk_path(Path0),
	    ModTestP = {not member(no_module_tests, Flags),
			exref_p(Flags)},
	    case get_release(RelName, Path, ModTestP, machine(Flags)) of
		{ok, Release, Appls, Warnings} ->
		    generate_script(RelName, Output, Release, Appls, Flags),
		    return(ok,Warnings,Flags);
		Error ->
		    return(Error,[],Flags)
	    end;
	{R_Path, R_Sil, R_Loc, R_Test, R_Var, R_Mach, R_Xref, R_XrefApps, ErrorVars} ->
	    badarg(make_script, ErrorVars, [RelName, Flags])
    end;

make_script(RelName, Output, Flags) when list(Flags) ->
    badarg(make_script,RelName,[RelName, Flags]);
make_script(RelName, Output, Flags) ->
    badarg(make_script,Flags,[RelName, Flags]).

badarg(Func, BadArg, Args) ->
    exit({{badarg,BadArg},{systools_make,Func,Args}}).

machine(Flags) ->
    case get_flag(machine,Flags) of
	{machine, Machine} when atom(Machine) -> Machine;
	_                                     -> false
    end.

get_path(Flags) ->
    case get_flag(path,Flags) of
	{path,Path} when list(Path) -> Path;
	_                           -> []
    end.

return(ok,Warnings,Flags) ->
    case member(silent,Flags) of
	true ->
	    {ok,?MODULE,Warnings};
	_ ->
	    io:format("~s",[format_warning(Warnings)]),
	    ok
    end;
return({error,Mod,Error},_,Flags) ->
    case member(silent,Flags) of
	true ->
	    {error,Mod,Error};
	_ ->
	    io:format("~s",[Mod:format_error(Error)]),
	    error
    end.

%%-----------------------------------------------------------------
%% Create a release package from a release file.
%% Options is a list of {path, Path} | silent |
%%    {dirs, [src,include,examples,..]} | {erts, ErtsDir} where path
%% sets the search path, silent supresses error message printing on console,
%% dirs includes the specified directories (per application) in the
%% release package and erts specifies that the erts-Vsn/bin directory
%% should be included in the release package and there it can be found.
%%
%% New options: {path,Path} can contain wildcards
%%              no_module_tests
%%              exref | {exref, [AppName]}
%%              {variables,[{Name,AbsString}]}
%%              {machine, jam | beam | vee}
%%              {var_tar, include | ownfile | omit}
%%
%% The tar file contains:
%%         lib/App-Vsn/ebin
%%                    /priv
%%                   [/src]
%%                   [/include]
%%                   [/doc]
%%                   [/examples]
%%                   [/...]
%%         Variable1.tar.gz
%%         ...
%%         VariableN.tar.gz
%%         releases/RelName.rel
%%                  RelVsn/start.boot
%%                         relup
%%                         sys.config
%%         erts-EVsn[/bin]
%%-----------------------------------------------------------------

make_tar(RelName) when list(RelName) ->
    make_tar(RelName, []);
make_tar(RelName) ->
    badarg(make_tar,RelName,[RelName]).

make_tar(RelName, Flags) when list(RelName), list(Flags) ->
    case check_args_tar(Flags) of
	{R_Path, R_Sil, R_Dirs, R_Erts, R_Test, R_Var, R_VarTar, 
	 R_Mach, R_Xref, R_XrefApps, []} ->
	    Path0 = get_path(Flags),
	    Path = mk_path(Path0),
	    ModTestP = {not member(no_module_tests, Flags),
			exref_p(Flags)},
	    case get_release(RelName, Path, ModTestP, machine(Flags)) of
		{ok, Release, Appls, Warnings} ->
		    case catch mk_tar(RelName, Release, Appls, Flags) of
			ok ->
			    return(ok,Warnings,Flags);
			Error ->
			    return(Error,Warnings,Flags)
		    end;
		Error ->
		    return(Error,[],Flags)
	    end;
	{R_Path, R_Sil, R_Dirs, R_Erts, R_Test, R_Var, R_VarTar, 
	 R_Mach, R_Xref, R_XrefApps, ErrorVars} ->
	    badarg(make_tar, ErrorVars, [RelName, Flags])
    end;
make_tar(RelName, Flags) when list(Flags) ->
    badarg(make_tar,RelName,[RelName, Flags]);
make_tar(RelName, Flags) ->
    badarg(make_tar,Flags,[RelName, Flags]).
    
%%______________________________________________________________________    
%% get_release(File, Path) ->
%% get_release(File, Path, ModTestP) ->
%% get_release(File, Path, ModTestP, Machine) ->
%%     {ok, #release, [{{Name,Vsn},#application}], Warnings} | {error, What}

get_release(File, Path) ->
    get_release(File, Path, true, false).

get_release(File, Path, ModTestP) ->
    get_release(File, Path, ModTestP, false).

get_release(File, Path, ModTestP, Machine) ->
    case catch get_release1(File, Path, ModTestP, Machine) of
	{error, Error} ->
	    {error, ?MODULE, Error};
	{'EXIT', Why} ->
	    {error, ?MODULE, {'EXIT',Why}};
	Answer ->
	    Answer
    end.
	
get_release1(File, Path, ModTestP, Machine) ->
    {ok, Release} = read_release(File, Path),
    {ok, Appls0} = collect_applications(Release, Path),
    {ok, Appls1} = check_applications(Appls0),
    {ok, Warnings} = check_modules(Appls1, Path, ModTestP, Machine),
    {ok, Appls} = sort_appls(Appls1),
    {ok, Release, Appls, Warnings}.

%%______________________________________________________________________    
%% read_release(File, Path) -> {ok, #release} | throw({error, What})

read_release(File, Path) ->
%    io:format("Searching for >>> ~s.rel <<< in the following Dirs: ~p~n",[File, Path]),
    case read_file(File ++ ".rel", ["."|Path]) of
	{ok, Release, FullName} ->
	    check_rel(Release);
	{error,Error} ->
	    throw({error,?MODULE,Error})
    end.

check_rel(Release) ->
    case catch check_rel1(Release) of
	{ok, {Name,Vsn,Evsn,Appl,Incl}} ->
	    {ok, #release{name=Name, vsn=Vsn,
			  erts_vsn=Evsn,
			  applications=Appl,
			  incl_apps=Incl}};
	{error, Error} ->
	    throw({error,?MODULE,Error});
	Error ->
	    throw({error,?MODULE,Error})
    end.

check_rel1({release, {Name,Vsn}, {erts,EVsn}, Appl}) when list(Appl) ->
    check_name(Name),
    check_vsn(Vsn),
    check_evsn(EVsn),
    {Appls,Incls} = check_appl(Appl),
    {ok, {Name,Vsn,EVsn,Appls,Incls}};
check_rel1(_) ->
    {error, badly_formatted_release}.

check_name(Name) ->
    case string_p(Name) of
	true ->
	    Name;
	_ ->
	    throw({error,{illegal_name, Name}})
    end.

check_vsn(Vsn) ->
    case string_p(Vsn) of
	true ->
	    Vsn;
	_ ->
	    throw({error,{illegal_form, Vsn}})
    end.

check_evsn(Vsn) ->
    case string_p(Vsn) of
	true ->
	    Vsn;
	_ ->
	    throw({error,{illegal_form, {erts,Vsn}}})
    end.

check_appl(Appl) ->
    case filter(fun({App,Vsn}) when atom(App) ->
			not string_p(Vsn);
		   ({App,Vsn,Incl}) when atom(App), list(Incl) ->
			case {string_p(Vsn), a_list_p(Incl)} of
			    {true, true} -> false;
			    _            -> true
			end;
		   ({App,Vsn,Type}) when atom(App), atom(Type) ->
			case {string_p(Vsn), is_app_type(Type)} of
			    {true, true} -> false;
			    _            -> true
			end;
		   ({App,Vsn,Type,Incl}) when atom(App),atom(Type),list(Incl) ->
			case {string_p(Vsn),is_app_type(Type),a_list_p(Incl)} of
			    {true, true, true} -> false;
			    _                  -> true
			end;
		   (_) ->
			true
		end,
		Appl) of
	[] ->
	    mandatory_applications(Appl),
	    split_app_incl(Appl);
	Illegal ->
	    throw({error, {illegal_applications,Illegal}})
    end.

mandatory_applications(Appl) ->
    AppNames = map(fun(AppT) -> element(1, AppT) end,
		   Appl),
    Mand = mandatory_applications(),
    case filter(fun(X) -> member(X, AppNames) end, Mand) of
	Mand ->
	    ok;
	_ ->
	    throw({error, {missing_mandatory_app, Mand}})
    end.

mandatory_applications() ->
    [kernel, stdlib].

split_app_incl(Appl) -> split_app_incl(Appl, [], []).

split_app_incl([{App,Vsn}|Appls], Apps, Incls) ->
    split_app_incl(Appls, [{App,Vsn,permanent}|Apps], Incls);
split_app_incl([{App,Vsn,Incl}|Appls], Apps, Incls) when list(Incl) ->
    split_app_incl(Appls, [{App,Vsn,permanent}|Apps], [{App,Incl}|Incls]);
split_app_incl([{App,Vsn,Type}|Appls], Apps, Incls) ->
    split_app_incl(Appls, [{App,Vsn,Type}|Apps], Incls);
split_app_incl([{App,Vsn,Type,Incl}|Appls], Apps, Incls) when list(Incl) ->
    split_app_incl(Appls, [{App,Vsn,Type}|Apps], [{App,Incl}|Incls]);
split_app_incl([], Apps, Incls) ->
    {reverse(Apps),reverse(Incls)}.

%%______________________________________________________________________
%% collect_applications(#release, Path) -> 
%%    {ok,[{{Name,Vsn},#application}]} |
%%    throw({error, What})
%% Read all the application files specified in the release descriptor

collect_applications(Release, Path) ->
    Appls = Release#release.applications,
    Incls = Release#release.incl_apps,
%    io:format("Reading application resource files for:\n~p\n", [Appls]),
    X = foldl(fun({Name,Vsn,Type}, {Ok, Errs}) ->
		      case read_application(to_list(Name), Vsn, Path, Incls) of
			  {ok, A} ->
			      case {A#application.name,A#application.vsn} of
				 {Name,Vsn} ->
				     {[{{Name,Vsn}, A#application{type=Type}} | Ok],
				      Errs};
				 E ->
				     {Ok, [{bad_application_name, {Name, E}} | Errs]}
			     end;
			  {error, What} ->
			      {Ok, [{error_reading, {Name, What}} | Errs]}
		      end
	      end, {[],[]}, Appls),
    case X of
	{A, []} ->
	    {ok, reverse(A)};
	{_, Errs} ->
	    throw({error, Errs})
    end.


%%______________________________________________________________________    
%% read_application(Name, Vsn, Path, Incls) -> {ok, #release} | {error, What}

read_application(Name, Vsn, Path, Incls) ->
%    io:format("Searching for ~s.app  vsn ~p in the following Dirs: ~p~n",[Name, Vsn, Path]),
    read_application(Name, Vsn, Path, Incls, false, no_fault).

read_application(Name, Vsn, [Dir|Path], Incls, Found, FirstError) ->
    case read_file(Name ++ ".app", [Dir]) of
	{ok, Term, FullName} ->
	    case parse_application(Term, FullName, Vsn, Incls) of
		{error, {no_valid_version, {Vsn, OtherVsn}}} when FirstError == no_fault ->
		    NFE = {no_valid_version, {{"should be", Vsn}, 
					       {"found file", filename:join(Dir, Name++".app"),
						OtherVsn}}},
		    read_application(Name, Vsn, Path, Incls, true, NFE);
		{error, {no_valid_version, {Vsn, OtherVsn}}} ->
			    read_application(Name, Vsn, Path, Incls, true, FirstError);
		Res ->
		    Res
	    end;
	{error, {parse, _File, {Line, Mod, Err}}} when FirstError == no_fault ->
%	    io:format("Parse error in file ~p; ~p~n",
%		      [filename:join(Dir, Name++".app"), Err]),
	    read_application(Name, Vsn, Path, Incls, Found, 
			     {parse_error, {filename:join(Dir, Name++".app"), Line, Err}});
	{error, {parse, _File, Err}} ->
%	    io:format("Parse error in file ~p; ~p~n",
%		      [filename:join(Dir, Name++".app"), Err]),
	    read_application(Name, Vsn, Path, Incls, Found, FirstError);
	{error, Err} -> %% Not found
%	    io:format("Error with file ~p; ~p~n",
%		      [filename:join(Dir, Name++".app"),Err]),
	    read_application(Name, Vsn, Path, Incls, Found, FirstError)
    end;
read_application(Name, Vsn, [], _, true, no_fault) ->
    {error, {application_vsn, {Name,Vsn}}};
read_application(Name, Vsn, [], _, true, FirstError) ->
    {error, FirstError};
read_application(Name, _, [], _, _, no_fault) ->
    {error, {not_found, Name ++ ".app"}};
read_application(Name, _, [], _, _, FirstError) ->
    {error, FirstError}.

parse_application({application, Name, Dict}, File, Vsn, Incls)
  when atom(Name),
       list(Dict) ->
%    io:format("Trying file ~p~n", [File]),
    Items = [vsn,id,description,modules,registered,
	     applications,included_applications,mod,start_phases,env,maxT,maxP],
    case catch get_items(Items, Dict) of
	[Vsn,Id,Desc,Mods,Regs,Apps,Incs0,Mod,Phases,Env,MaxT,MaxP] ->
	    case override_include(Name, Incs0, Incls) of
		{ok, Incs} ->
		    {ok, #application{name=Name,
				      vsn=Vsn,
				      id=Id,
				      description=Desc,
				      modules=Mods,
				      uses=Apps,
				      includes=Incs,
				      regs=Regs,
				      mod=Mod,
				      start_phases=Phases,
				      env=Env,
				      maxT=MaxT,
				      maxP=MaxP,
				      dir=filename:dirname(File)}};
		{error, IncApps} ->
		    {error, {override_include, IncApps}}
	    end;
	[OtherVsn,_,_,_,_,_,_,_,_,_,_,_] ->
	    {error, {no_valid_version, {Vsn, OtherVsn}}};
	Err ->
%	    io:format("Error. Got version ~p, wanted ~p~n",
%		      [Vsn1, Vsn]),
%	    io:format("Error ~p ~n",[Err]),
	    {error, {Err, {application, Name, Dict}}}
    end;
parse_application(Other, _, _, _) ->
    {error, {badly_formatted_application, Other}}.

%% Test if all included applications specifed in the .rel file
%% exists in the {included_applications,Incs} specified in the
%% .app file.
override_include(Name, Incs, Incls) ->
    case keysearch(Name, 1, Incls) of
	{value, {Name, I}} ->
	    case specified(I, Incs) of
		[] ->
		    {ok, I};
		NotSpec ->
		    {error, NotSpec}
	    end;
	_ ->
	    {ok, Incs}
    end.

specified([App|Incls], Spec) ->
    case member(App, Spec) of
	true ->
	    specified(Incls, Spec);
	_ ->
	    [App|specified(Incls, Spec)]
    end;
specified([], _) ->
    [].

get_items([H|T], Dict) ->
    Item = check_item(keysearch(H, 1, Dict),H),
    [Item|get_items(T, Dict)];
get_items([], Dict) ->
    [].

check_item({_,{mod,{M,A}}},_) when atom(M) ->
    {M,A};
check_item({_,{vsn,Vsn}},I) ->
    case string_p(Vsn) of
	true -> Vsn;
	_ -> throw({bad_param, I})
    end;
check_item({_,{id,Id}},I) ->
    case string_p(Id) of
	true -> Id;
	_ -> throw({bad_param, I})
    end;
check_item({_,{description,Desc}},I) ->
    case string_p(Desc) of
	true -> Desc;
	_ -> throw({bad_param, I})
    end;
check_item({_,{applications,Apps}},I) ->
    case a_list_p(Apps) of
	true -> Apps;
	_ -> throw({bad_param, I})
    end;
check_item({_,{included_applications,Apps}},I) ->
    case a_list_p(Apps) of
	true -> Apps;
	_ -> throw({bad_param, I})
    end;
check_item({_,{registered,Regs}},I) ->
    case a_list_p(Regs) of
	true -> Regs;
	_ -> throw({bad_param, I})
    end;
check_item({_,{modules,Mods}},I) ->
    case mod_list_p(Mods) of
	true -> Mods;
	_ -> throw({bad_param, I})
    end;
check_item({_,{start_phases,Phase}},I) ->
    case t_list_p(Phase) of
	true -> Phase;
	_ -> throw({bad_param, I})
    end;
check_item({_,{env,Env}},I) ->
    case t_list_p(Env) of
	true -> Env;
	_ -> throw({bad_param, I})
    end;
check_item({_,{maxT,MaxT}},I) ->
    case MaxT of
	MaxT when integer(MaxT), MaxT > 0 -> MaxT;
	infinity -> infinity;
	_ -> throw({bad_param, I})
    end;
check_item({_,{maxP,MaxP}},I) ->
    case MaxP of
	MaxP when integer(MaxP), MaxP > 0 -> MaxP;
	infinity -> infinity;
	_ -> throw({bad_param, I})
    end;
check_item(false, included_applications) -> % optional !
    [];
check_item(false, mod) -> % mod is optional !
    [];
check_item(false, env) -> % env is optional !
    [];
check_item(false, id) -> % id is optional !
    [];
check_item(false, start_phases) -> % start_phases is optional !
    undefined;
check_item(false, maxT) -> % maxT is optional !
    infinity;
check_item(false, maxP) -> % maxP is optional !
    infinity;
check_item(_, Item) ->
    throw({missing_param, Item}).

%%______________________________________________________________________
%% check_applications([{{Name,Vsn},#application}]) ->
%%    ok | throw({error, Error})
%% check that all referenced applications exists and that no
%% application register processes with the same name.
%% Check that included_applications are not specified as used
%% in another application.

check_applications(Appls) ->
    undef_appls(Appls),
    dupl_regs(Appls),
    %% Make a list Incs = [{Name,App,AppVsn,Dir}]
    Incs = [{IncApp,App,Appv,A#application.dir} ||
	       {{App,Appv},A} <- Appls,
	       IncApp <- A#application.includes],
    dupl_incls(Incs),
    Res = add_top_apps_to_uses(Incs, Appls, []),
    {ok, Res}.



undef_appls(Appls) ->
    case undefined_applications(Appls) of
	[] ->
	    ok;
	L ->
	    throw({error, {undefined_applications, make_set(L)}})
    end.

dupl_regs(Appls) ->
    %% Make a list Regs = [{Name,App,AppVsn,Dir}]
    Regs = [{Name,App,Appv,A#application.dir} ||
	       {{App,Appv},A} <- Appls,
	       Name <- A#application.regs],
    case duplicates(Regs) of
	[] ->
	    ok;
	Dups ->
	    throw({error, {duplicate_register, Dups}})
    end.


dupl_incls(Incs) ->
    case duplicates(Incs) of
	[] ->
	    ok;
	Dups ->
	    throw({error, {duplicate_include, Dups}})
    end.



%% If an application uses another application which is included in yet another
%% application, e.g. X uses A, A is included in T; then the A application 
%% in the X applications uses-variable is changed to the T application's 
%% Top application to ensure the start order. 
%% Exception: if both X and A have the same top, then it is not
%% added to avoid circular dependencies.
%%
%% add_top_apps_to_uses( list of all included applications in the system,
%%                       list of all applications in the system,
%%                       temporary result) -> new list of all applications
add_top_apps_to_uses(InclApps, [], Res) ->
    %% InclApps = [{IncApp, App, AppVsn, Dir}]
    Res;
add_top_apps_to_uses(InclApps, [{Name,Appl} | Appls], Res) ->
    MyTop = find_top_app(Appl#application.name, InclApps),
    F = fun(UsedApp, AccIn) when UsedApp == MyTop ->
		%% UW980513 This is a special case: The included app uses
		%% its own top app. We'll allow it, but must remove the top
		%% app from the uses list.
		AccIn -- [MyTop];
	   (UsedApp, AccIn) ->
		case lists:keysearch(UsedApp, 1, InclApps) of
		    false ->
			AccIn;
		    {value, {_,DependApp,_,_}} ->
			UsedAppTop = find_top_app(DependApp, InclApps),
			case {lists:member(UsedAppTop, AccIn), MyTop} of
			    {true, _} ->
				%% the top app is already in the uses list,
				%% remove UsedApp
				AccIn -- [UsedApp];
			    {_, UsedAppTop} ->
				%% both are included in the same app
				AccIn;
			    _ ->
				%% change the used app to the used app's
				%% top application
				AccIn1 = AccIn -- [UsedApp],
				AccIn1 ++ [UsedAppTop]
			end
		end
	end,
	  
    NewUses = foldl(F, Appl#application.uses, Appl#application.uses),
    add_top_apps_to_uses(InclApps, Appls, 
			 Res++[{Name, Appl#application{uses = NewUses}}]).



find_top_app(App, InclApps) ->
    case lists:keysearch(App, 1, InclApps) of
	false ->
	    App;
	{value, {_,TopApp,_,_}} ->
	    find_top_app(TopApp, InclApps)
    end.

 

%%______________________________________________________________________
%% undefined_applications([{{Name,Vsn},#application}]) ->
%%   [Name] list of applications that were declared in
%%   use declarations but are not contained in the release descriptor

undefined_applications(Appls) ->
    Uses = append(map(fun({_,A}) ->
			      A#application.uses ++ A#application.includes
		      end, Appls)),
    Defined = map(fun({{X,_},_}) -> X end, Appls),
    filter(fun(X) -> not member(X, Defined) end, Uses).

%%______________________________________________________________________
%% check_modules(Appls, Path, TestP, Machine) ->
%%  {ok, Warnings} | throw({error, What})
%%   where Appls = [{App,Vsn}, #application}]
%%   performs logical checking that we can find all the modules
%%   etc.

check_modules(Appls, Path, TestP, Machine) ->
%    io:format("Checking modules\n", []),
    %% first check that all the module names are unique
    %% Make a list M1 = [{Mod,Vsn,App,AppVsn,Dir}]
    %%   where Vsn = '$$ignore$$' | Specified
    M1 = [{Mod,Vsn,App,Appv,A#application.dir} ||
	     {{App,Appv},A} <- Appls,
	     {Mod,Vsn} <- get_mod_vsn(A#application.modules)],
    case duplicates(M1) of
	[] ->
	    case check_mods(M1, Appls, Path, TestP, Machine) of
		{error, Errors} ->
		    throw({error, {modules, Errors}});
		Return ->
		    Return
	    end;
	Dups ->
%	    io:format("** ERROR Duplicate modules: ~p\n", [Dups]),
	    throw({error, {duplicate_modules, Dups}})
    end.

get_mod_vsn([{Mod,Vsn}|Mods]) ->
    [{Mod,Vsn}|get_mod_vsn(Mods)];
get_mod_vsn([Mod|Mods]) ->
    [{Mod,'$$ignore$$'}|get_mod_vsn(Mods)];
get_mod_vsn([]) ->
    [].

%%______________________________________________________________________
%% Check that all modules exists and that the specified version corresponds
%% to the version in the module's source code.
%% Use the module extension of the running machine as extension for
%% the checked modules.

check_mods(Modules, Appls, Path, {true, ExrefP}, Machine) ->
    Ext = objfile_extension(Machine),
    IncPath = create_include_path(Appls, Path),
    start_exref(IncPath, ExrefP),
    Res = append(map(fun(ModT) ->
			     {Mod,Vsn,App,_,Dir} = ModT,
			     case check_mod(Mod,Vsn,App,Dir,Ext,
					    IncPath,ExrefP) of
				 ok ->
				     [];
				 {error, Error} ->
				     [{error,{Error, ModT}}];
				 {warning, Warn} ->
				     [{warning,{Warn,ModT}}]
			     end
		     end,
		     Modules)),
    case filter(fun({error, _}) -> true;
		   (_)          -> false
		end,
		Res) of
	[] ->
	    Warnings = Res ++ check_exref(Res, Appls, ExrefP),
	    stop_exref(ExrefP),
	    {ok, filter(fun({warning, _}) -> true;
			   (_)            -> false
			end,
			Warnings)};
	Errors ->
	    stop_exref(ExrefP),
	    {error, Errors}
    end;
check_mods(_, _, _, _, _) ->
    {ok, []}.

%%
%% Perform cross reference checks between all modules specified
%% in .app files.
%%
exref_p(Flags) ->
    case member(exref, Flags) of
	true ->
	    exists_exref(true);
	_ ->
	    case get_flag(exref, Flags) of
		{exref, Appls} when list(Appls) ->
		    case a_list_p(Appls) of
			true -> exists_exref({true, Appls});
			_    -> false
		    end;
		_ ->
		    false
	    end
    end.

exists_exref(Flag) ->
    case code:ensure_loaded(exref) of
	{error, _} -> false;
	_          -> Flag
    end.

start_exref(_, false) ->
    ok;
start_exref(IncPath, _) ->
    case catch exref:start() of
	{ok, _Pid} ->
	    ok;
	{'EXIT', {_String, {error, {already_started, _Pid}}}} ->
	    exref:stop(), %% Clear out any previous data
	    exref:start()
    end,
    exref:includes(IncPath).

stop_exref(false) -> ok;
stop_exref(_)     -> exref:stop().

load_module_exref(_, _, _, false) ->
    ok;
load_module_exref(Dir, Mod, App, {true, Apps}) ->
    case member(App, Apps) of
	true ->
	    load_module_exref(Dir, Mod, App, true);
	_ ->
	    ok
    end;
load_module_exref(Dir, Mod, _, _) ->
    exref:directory_module(Dir, Mod, [check_lib]).

check_exref(_, _, false) ->
    [];
check_exref(Warnings, Appls, ExrefP) ->
    AppMods = map(fun({{App,_},Appl}) ->
			  {App,Appl#application.modules}
		  end,
		  Appls),
    NotExrefd = not_exrefd_mods(ExrefP, Appls),
    NotFound = append(map(fun({warning,{source_not_found,{Mod,_,_,_,_}}}) ->
				  [Mod];
			     (_) ->
				  []
			  end, Warnings)),
    case exref:analyse(undefined_functions) of 
	{undefined_functions, _X, Undefd0} ->
	    Warn = calls_not_exrefd_apps(Undefd0, ExrefP, Appls,
					 NotExrefd, AppMods),
	    case filter_modules(Undefd0, NotExrefd ++ NotFound) of
		[]     -> Warn ++ [];
		Undefd -> Warn ++ [{warning, {exref_undef, Undefd}}]
	    end;
	_ ->
	    []
    end.
		 
%% All modules in not exref'd applications.
not_exrefd_mods({true, Apps}, Appls) ->
    append(map(fun({{App, _}, Appl}) ->
		       case member(App, Apps) of
			   false -> to_names(Appl#application.modules);
			   _     -> []
		       end
	       end,
	       Appls));
not_exrefd_mods(_, _) ->
    [].

to_names([{Mod,_}|Mods]) -> [Mod|to_names(Mods)];
to_names([Mod|Mods])     -> [Mod|to_names(Mods)];
to_names([])             -> [].

%%
%% Do not generate warnings for undefined functions located
%% in modules for which no source code is found.
%% For this modules other warnings are reported.
%% Do not generate warnings for modules located in applications
%% not exref'ed.
%% The exref module itself is not exref'd !!
%%
filter_modules(Undefd, NotFound0) ->
    NotFound = [exref|NotFound0],
    filter(fun({undefined, {Mod,_,_}, Called}) ->
		   case member(Mod, NotFound) of
		       true -> false;
		       _    -> valid_undef_p(Called)
		   end;
	      (_) ->
		   false
	   end,
	   Undefd).

%%
%% Make a warning for applications calling functions
%% in not exref'd applications.
%%
calls_not_exrefd_apps(Undefd, {true, Apps}, Appls, NotExrefd, AppMods) ->
    AppRel =
	append(map(fun({undefined, {Mod,_,_}, Called}) ->
			   case {member(Mod, NotExrefd),
				 valid_undef_p(Called)} of
			       {true, true} ->
				   App = application(Mod,AppMods),
				   called_from_appls(App, Called, AppMods);
			       _ ->
				   []
			   end
		   end,
		   Undefd)),
    case ordsets:set_to_list(ordsets:list_to_set(AppRel)) of
	[] ->  [];
	W  ->  [{warning, {exref_app_rel, W}}]
    end;
calls_not_exrefd_apps(_, _, _, _, _) ->
    [].

%% We know that Mod exists in an application.
application(Mod, [{App,Mods}|Apps]) ->
    case app_mod(Mod, Mods) of
	true -> App;
	_    -> application(Mod, Apps)
    end.

app_mod(Mod, [Mod|_])      -> true;
app_mod(Mod, [{Mod, _}|_]) -> true;
app_mod(Mod, [_|Mods])     -> app_mod(Mod, Mods);
app_mod(_, [])             -> false.

called_from_appls(App, Called, AppMods) ->
    map(fun({called_by, {_, _, Mod, _, _}}) ->
		{application(Mod, AppMods), App}
	end, Called).

%%
%% Do not generate warnings for undefined functions called
%% from the Filter modules. As this modules calls for example
%% the interpreter, and snmp stuff not included in all releases.
%%
valid_undef_p(Called) ->
    Filter = [c,shell_default,error_handler,otp_mib,erl_lint],
    case filter(fun({called_by, {_, _, Mod, _, _}}) ->
			not member(Mod, Filter);
		   (_) ->
			false
		end,
		Called) of
	[] -> false;
	_  -> true
    end.

objfile_extension(false) ->
    code:objfile_extension();
objfile_extension(Machine) ->
    "." ++ atom_to_list(Machine).

check_mod(Mod,Vsn,App,Dir,Ext,IncPath,ExrefP) ->
    case file:read_file_info(filename:join(Dir, to_list(Mod) ++ Ext)) of
	{ok,FileInfo} ->
	    LastModTime = FileInfo#file_info.mtime,
	    load_module(Mod,Vsn,App,Dir,LastModTime,IncPath,ExrefP);
	_ ->
	    {error, module_not_found}
    end.

load_module(Mod,Vsn,App,Dir,ObjModTime,IncPath,ExrefP) ->
    {SrcDirs,IncDirs}= smart_guess(Dir,IncPath),
    case locate_src(Mod,SrcDirs) of
	{ok,FDir,File,LastModTime} ->
	    load_module_exref(FDir,Mod,App,ExrefP),
	    if
		LastModTime > ObjModTime ->
		    {warning, {obj_out_of_date, File}};
		true ->
		    ok
	    end;
	_ ->
	    {warning, source_not_found}
    end.

locate_src(Mod,[Dir|Dirs]) ->
    File = filename:join(Dir, to_list(Mod) ++ ".erl"),
    case file:read_file_info(File) of
	{ok,FileInfo} ->
	    LastModTime = FileInfo#file_info.mtime,
	    {ok,Dir,File,LastModTime};
	_ ->
	    locate_src(Mod,Dirs)
    end;
locate_src(_,[]) ->
    false.

%%______________________________________________________________________
%% smart_guess(Dir,IncludePath) -> {[Dirs],[IncDirs]}
%% Guess the src code and include directory. If dir contains .../ebin src-dir
%% should be one of .../src or .../src/e_src
%% If dir does not contain .../ebin set dir to the same directory.

smart_guess(Dir,IncPath) ->
    case reverse(filename:split(Dir)) of
	["ebin"|D] ->
	    D1 = reverse(D),
	    Dirs = [filename:join(D1 ++ ["src"]),
		    filename:join(D1 ++ ["src", "e_src"])],
	    {Dirs,Dirs ++ IncPath};
	_ ->
	    {[Dir],[Dir] ++ IncPath}
    end.

%%______________________________________________________________________
%% generate_script(RelName, #release, 
%%                 [{{Name,Vsn},#application}], Flags) ->
%%                         ok | {error, Error}
%%    Writes a script (a la magnus) to the file File.script
%%    and a bootfile to File.boot.

generate_script(RelName, Output, Release, Appls, Flags) ->
    PathFlag = path_flag(Flags),
    Variables = get_variables(Flags),
    Script = {script, {Release#release.name,Release#release.vsn},
	      [{preLoaded, preloaded()},
	       {progress, preloaded},
	       {path, create_mandatory_path(Appls, PathFlag, Variables)},
	       {primLoad, mandatory_modules()},
	       {kernel_load_completed},
	       {progress, kernel_load_completed}] ++
	      load_appl_mods(Appls, mandatory_modules() ++ preloaded(),
			     PathFlag, Variables) ++
	      [{path, create_path(Appls, PathFlag, Variables)}] ++
	      create_kernel_procs(Appls) ++
	      create_load_appls(Appls) ++
	      create_start_appls(Appls) ++
	      script_end()
	     },
%    io:format("Writing script file: ~p\n", [RelName ++ ".script"]),
    write_script(Output ++ ".script", Script),
%    io:format("Writing boot file: ~p\n", [RelName ++ ".boot"]),
    file:write_file(Output ++ ".boot", term_to_binary(Script)),
    ok.

path_flag(Flags) ->
    case {member(local,Flags), member(otp_build, Flags)} of
	{true, _} -> local;
	{_, true} -> otp_build;
	{_, _}    -> true
    end.

get_variables(Flags) ->
    case get_flag(variables, Flags) of
	{variables, Variables} when list(Variables) ->
	    valid_variables(Variables);
	_ ->
	    []
    end.

valid_variables([{Var,Path}|Variables]) when list(Var), list(Path) ->
    [{Var,rm_tlsl(Path)}|valid_variables(Variables)];
valid_variables([{Var,Path}|Variables]) when atom(Var), list(Path) ->
    [{to_list(Var),rm_tlsl(Path)}|valid_variables(Variables)];
valid_variables([_|Variables]) ->
    valid_variables(Variables);
valid_variables(_) ->
    [].

rm_tlsl(P) -> rm_tlsl1(reverse(P)).
rm_tlsl1([$/|P]) -> rm_tlsl1(P);
rm_tlsl1(P) -> reverse(P).
  
%%______________________________________________________________________
%% Start all applications.
%% Do not start applications that are included applications !

create_start_appls(Appls) ->
    Included = append(map(fun({_,A}) ->
				  A#application.includes
		      end, Appls)),
    create_start_appls(Appls, Included).

create_start_appls([{_,A}|T], Incl) ->
    App = A#application.name,
    case lists:member(App, Incl) of
	false when A#application.type == none ->
	    create_start_appls(T, Incl);
	false when A#application.type == load ->
	    create_start_appls(T, Incl);
	false ->
	    [{apply, {application, start_boot, [App,A#application.type]}} |
	     create_start_appls(T, Incl)];
	_ ->
	    create_start_appls(T, Incl)
    end;
create_start_appls([], _) ->
    [].

%%______________________________________________________________________
%% Load all applications.

create_load_appls([{{kernel,_},_}|T]) -> %Already added !!
    create_load_appls(T);
create_load_appls([{_,A}|T]) when A#application.type == none ->
    create_load_appls(T);
create_load_appls([{_,A}|T]) ->
    [{apply, {application, load, [pack_app(A)]}} |
     create_load_appls(T)];
create_load_appls([]) ->
    [{progress, applications_loaded}].

%%______________________________________________________________________
%% The final part of the script.

script_end() ->
    [{apply, {c, erlangrc, []}},
     {progress, started}].

%%-----------------------------------------------------------------
%% Function: sort_appls(Appls) -> {ok, Appls'} | throw({error, Error})
%% Types: Appls = {{Name, Vsn}, #application}]
%% Purpose: Sort applications according to dependencies among
%%          applications.  If order doesn't matter, use the same
%%          order as in the original list.
%% Alg. written by Ulf Wiger 970917 (etxuwig@etxb.ericsson.se)
%% Mod. by mbj
%%-----------------------------------------------------------------
sort_appls(Appls) -> {ok, sort_appls(Appls, [], [], [])}.

sort_appls([{N, A}|T], Missing, Circular, Visited) ->
    {Name,_Vsn} = N,
    {Uses, T1, NotFnd1} = find_all(Name, A#application.uses, T, Visited, [], []),
    {Incs, T2, NotFnd2} = find_all(Name, A#application.includes, T1, Visited, [], []),
    Missing1 = NotFnd1 ++ NotFnd2 ++ Missing,
    case Uses ++ Incs of
	[] -> 
	    %% No more app that must be started before this one is found;
	    %% they are all already taken care of (and present in Visited
	    %% list)
	    [{N, A}|sort_appls(T, Missing1, Circular, [N|Visited])];
	L ->
	    %% The apps in L must be started before the app.
	    %% Check if we have already taken care of some app in L,
	    %% in that case we have a circular dependency.
	    NewCircular = [N1 || {N1, _} <- L, N2 <- Visited, N1 == N2],
	    Circular1 = case NewCircular of 
			    [] -> Circular; 
			    _ -> [N | NewCircular] ++ Circular
			end,
	    %% L must be started before N, try again, with all apps
	    %% in L added before N.
	    Apps = del_apps(NewCircular, L ++ [{N, A}|T2]),
	    sort_appls(Apps, Missing1, Circular1, [N|Visited])
    end;
sort_appls([], [], [], _) ->
    [];
sort_appls([], Missing, [], _) ->
    %% this has already been checked before, but as we have the info...
    throw({error, {undefined_applications, make_set(Missing)}});
sort_appls([], [], Circular, _) ->
    throw({error, {circular_dependencies, make_set(Circular)}});
sort_appls([], Missing, Circular, _) ->
    throw({error, {apps, [{circular_dependencies, make_set(Circular)}, 
			  {undefined_applications, make_set(Missing)}]}}).

find_all(CheckingApp, [Name|T], L, Visited, Found, NotFound) ->
    case find_app(Name, L) of
	{value, App} ->
	    {A,R} = App,
	    %% It is OK to have a dependecy like
	    %% X includes Y, Y uses X.
	    case lists:member(CheckingApp, R#application.includes) of
		true ->
		    case lists:keymember(Name, 1, Visited) of
			true ->
			    find_all(CheckingApp, T, L, Visited, Found, NotFound);
			false ->
			    find_all(CheckingApp, T, L, Visited, Found, [Name|NotFound])
		    end;
		false ->
		    find_all(CheckingApp, T, L -- [App], Visited, [App|Found], NotFound)
	    end;
	false ->
	    case lists:keymember(Name, 1, Visited) of
		true ->
		    find_all(CheckingApp, T, L, Visited, Found, NotFound);
		false ->
		    find_all(CheckingApp, T, L, Visited, Found, [Name|NotFound])
	    end
    end;
find_all(CheckingApp, [], L, Visited, Found, NotFound) ->
    {Found, L, NotFound}.
	    
find_app(Name, [{{Name,Vsn}, Application}|_]) ->
    {value, {{Name,Vsn},Application}};
find_app(Name, [_|T]) ->
    find_app(Name, T);
find_app(Name, []) ->
    false.

del_apps([Name|T], L) ->
    del_apps(T, lists:keydelete(Name, 1, L));
del_apps([], L) ->
    L.


%%______________________________________________________________________    
%% Create the load path used in the generated script.
%% If PathFlag is true a script intended to be used as a complete
%% system (e.g. in an embbeded system), i.e. all applications are
%% located under $ROOT/lib.
%% Otherwise all paths are set according to dir per application.

%% Create the complete path.
create_path(Appls, PathFlag, Variables) ->
    make_set(map(fun({{Name,Vsn},App}) ->
			 cr_path(Name, Vsn, App, PathFlag, Variables)
		 end,
		 Appls)).

%% Create the path to a specific application.
%% (The otp_build flag is only used for OTP internal system make)
cr_path(Name, Vsn, _, true, []) ->
    filename:join(["$ROOT", "lib", to_list(Name) ++ "-" ++ Vsn, "ebin"]);
cr_path(Name, Vsn, App, true, Variables) ->
    Dir = App#application.dir,
    N = to_list(Name),
    Tail = [N ++ "-" ++ Vsn, "ebin"],
    case variable_dir(Dir, N, Vsn, Variables) of
	{ok, VarDir} ->
	    filename:join([VarDir] ++ Tail);
	_ ->
	    filename:join(["$ROOT", "lib"] ++ Tail)
    end;
cr_path(Name, _, _, otp_build, _) ->
    filename:join(["$ROOT", "lib", to_list(Name), "ebin"]);
cr_path(_, _, App, _, _) ->
    filename:absname(App#application.dir).

variable_dir(Dir, Name, Vsn, [{Var,Path}|Variables]) ->
    case lists:prefix(Path,Dir) of
	true ->
	    D0 = strip_prefix(Path, Dir),
	    case strip_name_ebin(D0, Name, Vsn) of
		{ok, D} ->
		    {ok, filename:join(["\$" ++ Var] ++ D)};
		_ ->
		    %% We know at least that we are located
		    %% under the variable dir.
		    {ok, filename:join(["\$" ++ Var] ++ D0)}
	    end;
	_ ->
	    variable_dir(Dir, Name, Vsn, Variables)
    end;
variable_dir(Dir, _, _, []) ->
    false.

strip_prefix(Path, Dir) ->
    L = length(filename:split(Path)),
    lists:nthtail(L, filename:split(Dir)).

strip_name_ebin(Dir, Name, Vsn) ->
    FullName = Name ++ "-" ++ Vsn,
    case reverse(Dir) of
	["ebin",Name|D]     -> {ok, reverse(D)};
	["ebin",FullName|D] -> {ok, reverse(D)};
	_                   -> false
    end.

%% Create the path to the kernel and stdlib applications.
create_mandatory_path(Appls, PathFlag, Variables) ->
    Dirs = [kernel, stdlib],
    make_set(map(fun({{Name,Vsn}, A}) ->
			 case lists:member(Name, Dirs) of
			     true ->
				 cr_path(Name, Vsn, A, PathFlag, Variables);
			     _ ->
				 ""
			 end
		 end,
		 Appls)).

%%______________________________________________________________________    
%% Load all modules, except those in Mandatory_modules.

load_appl_mods([{{Name,Vsn},A}|Appls], Mand, PathFlag, Variables) ->
    Mods = map(fun({Mod,_}) -> Mod;
		  (Mod)     -> Mod
	       end,
	       A#application.modules),
    [{path, [cr_path(Name, Vsn, A, PathFlag, Variables)]},
     {primLoad, filter(fun(Mod) -> not member(Mod, Mand) end, Mods)} |
     load_appl_mods(Appls, Mand, PathFlag, Variables)];
load_appl_mods([], _, _, _) ->
    [{progress, modules_loaded}].

%%______________________________________________________________________    
%% Pack an application to an application term.

pack_app(#application{name=Name,vsn=V,id=Id,description=D,modules=M,
		      uses=App,includes=Incs,regs=Regs,mod=Mod,start_phases=SF,
		      env=Env,maxT=MaxT,maxP=MaxP}) ->
    {application, Name,
     [{description,D},
      {vsn,V},
      {id,Id},
      {modules, M},
      {registered, Regs},
      {applications, App},
      {included_applications, Incs},
      {env, Env},
      {start_phases, SF},
      {maxT, MaxT},
      {maxP, MaxP} |
      behave(Mod)]}.

behave([]) ->
    [];
behave(Mod) ->
    [{mod, Mod}].

%%______________________________________________________________________    
%% mandatory modules; this modules must be loaded before processes
%% can be started. These are a collection of modules from the kernel
%% and stdlib applications.
%% Nowadays, error_handler dynamically loads almost every module.
%% These two must still be there though.

mandatory_modules() ->
    [erlang, error_handler].

%%______________________________________________________________________    
%% This is the modules that are preloaded into the Erlang system.

preloaded() -> [init, erl_prim_loader].

%%______________________________________________________________________    
%% Kernel processes; processes that are specially treated by the init
%% process. If a kernel process terminates the whole system terminates.
%% kernel_processes() -> [{Name, Mod, Func, Args}]
%%    where Args is a term or a fun taking the list of applications as arg.

kernel_processes() ->
    [{heart, heart, start, []},
     {error_logger, error_logger, start_link, []},
     {application_controller, application_controller, start,
      fun(Appls) ->
              [{_,App}] = filter(fun({{kernel,_},App}) -> true;
                                    (_)                -> false
                                 end,
                                 Appls),
              [pack_app(App)]
      end}
    ].

%%______________________________________________________________________    
%% Create the kernel processes.

create_kernel_procs(Appls) ->
    map(fun({Name,Mod,Func,Args}) when function(Args) ->
                {kernelProcess, Name, {Mod, Func, Args(Appls)}};
           ({Name,Mod,Func,Args}) ->
                {kernelProcess, Name, {Mod, Func, Args}}
        end,
        kernel_processes()) ++
    [{progress, init_kernel_started}].

%%______________________________________________________________________    
%% Make a tar file of the release.
%% The tar file contains:
%%         lib/App-Vsn/ebin
%%                    /priv
%%                   [/src]
%%                   [/include]
%%                   [/doc]
%%                   [/examples]
%%                   [/...]
%%         Variable1.tar.gz
%%         ...
%%         VariableN.tar.gz
%%         releases/RelName.rel
%%                  RelVsn/start.boot
%%                         relup
%%                         sys.config
%%         erts-EVsn[/bin]
%%
%% The VariableN.tar.gz files can also be stored as own files not included
%% in the main tar file or they can be omitted using the var_tar option.

mk_tar(RelName, Release, Appls, Flags) ->
    TarName = RelName ++ ".tar.gz",
    Tar = open_main_tar(TarName),
    case catch mk_tar(Tar, RelName, Release, Appls, Flags) of
	{error,Error} ->
	    del_tar(Tar, TarName),
	    {error,?MODULE,Error};
	{'EXIT',Reason} ->
	    del_tar(Tar, TarName),
	    {error,?MODULE,Reason};
	_ ->
	    close_tar(Tar),
	    ok
    end.

open_main_tar(TarName) ->
    case catch open_tar(TarName) of
	{error, Error} ->
	    throw({error,?MODULE,Error});
	Tar ->
	    Tar
    end.

mk_tar(Tar, RelName, Release, Appls, Flags) ->
    Variables = get_variables(Flags),
    add_applications(Appls, Tar, Variables, Flags, false),
    add_variable_tars(Variables, Appls, Tar, Flags),
    add_system_files(Tar, RelName, Release, Flags),
    add_erts_bin(Tar, Release, Flags).
    
add_applications(Appls, Tar, Variables, Flags, Var) ->
    Res = foldl(fun({{Name,Vsn},App}, Errs) ->
		  case catch add_appl(to_list(Name), Vsn, App,
				      Tar, Variables, Flags, Var) of
		      ok ->
			  Errs;
		      {error, What} ->
			  [{error_add_appl, {Name,What}}|Errs]
		  end
	       end, [], Appls),
    case Res of
	[] ->
	    ok;
	Errors ->
	    throw({error, Errors})
    end.

%%______________________________________________________________________    
%% Create a tar file for each Variable directory.
%% Deletes the temporary tar file.

add_variable_tars([Variable|Variables], Appls, Tar, Flags) ->
    add_variable_tar(Variable, Appls, Tar, Flags),
    add_variable_tars(Variables, Appls, Tar, Flags);
add_variable_tars([], _, _, _) ->
    ok.

add_variable_tar({Variable,P}, Appls, Tar, Flags) ->    
    case var_tar_flag(Flags) of
	omit ->
	    ok;
	Flag ->
	    TarName = Variable ++ ".tar.gz",
	    VarTar = open_tar(TarName),
	    case catch add_applications(Appls, VarTar, [{Variable,P}],
					Flags, Variable) of
		ok when Flag == include ->
		    close_tar(VarTar),
		    add_to_tar(Tar, TarName, TarName),
		    del_file(TarName);
		ok when Flag == ownfile ->
		    close_tar(VarTar),
		    ok;
		Error ->
		    del_tar(VarTar, TarName),
		    throw(Error)
	    end
    end.

var_tar_flag(Flags) ->
    case get_flag(var_tar, Flags) of
	{var_tar, Flag} ->
	    case member(Flag, [include, ownfile, omit]) of
		true -> Flag;
		_    -> include
	    end;
	_ ->
	    include
    end.

%%______________________________________________________________________    
%% Add all "other" files to Dir/releases/Svsn
%% add_system_files(Tar,Name,release#,Flags) -> ok | throw({error,Error})

add_system_files(Tar, RelName, Release, Flags) ->
    SVsn = Release#release.vsn,
    ToDir = filename:join(releases, SVsn),
    add_to_tar(Tar, RelName ++ ".boot", filename:join(ToDir, "start.boot")),
    catch add_to_tar(Tar, "relup", filename:join(ToDir, "relup")),
    catch add_to_tar(Tar, "sys.config", filename:join(ToDir, "sys.config")),
    catch add_to_tar(Tar, RelName ++ ".rel",
		     filename:join("releases", RelName ++ ".rel")),
    ok.

%%______________________________________________________________________    
%% Add either a application located under a variable dir or all other
%% applications to a tar file.
%% add_appl(Name,Vsn,application#,Tar,Variables,Flags,Var) ->
%%    ok | {error,Error}

add_appl(Name, Vsn, App, Tar, Variables, Flags, Var) ->
    AppDir = App#application.dir,
    case add_to(AppDir,Name,Vsn,Variables,Var) of
	false ->
	    ok;
	{ok, ToDir} ->
	    ADir = appDir(AppDir),
	    add_priv(ADir, ToDir, Tar),
	    case get_flag(dirs,Flags) of
		{dirs,Dirs} ->
		    add_dirs(ADir, Dirs, ToDir, Tar);
		_ ->
		    ok
	    end,
	    BinDir = filename:join(ToDir, "ebin"),
	    add_to_tar(Tar,
		       filename:join(AppDir, Name ++ ".app"),
		       filename:join(BinDir, Name ++ ".app")),
	    add_modules(map(fun({Mod,_}) -> to_list(Mod);
			       (Mod)     -> to_list(Mod)
			    end,
			    App#application.modules),
			Tar,
			AppDir,
			BinDir,
			objfile_extension(machine(Flags)))
    end.

%%______________________________________________________________________    
%% If an application directory contains a Variable (in AppDir) the
%% application will be placed in the tar file (if it is this Variable
%% we corrently is actually storing).

add_to(AppDir,Name,Vsn,Variables,Variable) ->
    case var_dir(AppDir,Name,Vsn,Variables) of
	{ok, Variable, RestPath} ->
	    {ok, filename:join(RestPath ++ [Name ++ "-" ++ Vsn])};
	{ok, _, _} ->
	    false;
	_ when Variable == false ->
	    {ok, filename:join("lib", Name ++ "-" ++ Vsn)};
	_ ->
	    false
    end.

var_dir(Dir, Name, Vsn, [{Var,Path}|Variables]) ->
    case lists:prefix(Path,Dir) of
	true ->
	    D0 = strip_prefix(Path, Dir),
	    case strip_name_ebin(D0, Name, Vsn) of
		{ok, D} ->
		    {ok, Var, D};
		_ ->
		    false
	    end;
	_ ->
	    var_dir(Dir, Name, Vsn, Variables)
    end;
var_dir(Dir, _, _, []) ->
    false.

appDir(AppDir) ->
    case reverse(filename:split(AppDir)) of
	["ebin"|Dir] -> filename:join(reverse(Dir));
	_            -> AppDir
    end.

add_modules(Modules, Tar, AppDir, ToDir, Ext) ->
    foreach(fun(Mod) ->
		    add_to_tar(Tar,
			       filename:join(AppDir, Mod ++ Ext),
			       filename:join(ToDir, Mod ++ Ext))
	    end, Modules).
		    
%%
%% Add own specified directories to include in the release.
%% If not found, skip it.
%%
add_dirs(AppDir, Dirs, ToDir, Tar) ->
    foreach(fun(Dir) -> catch add_dir(AppDir, to_list(Dir), ToDir, Tar) end,
	    Dirs).

add_dir(TopDir, Dir, ToDir, Tar) ->
    FromD = filename:join(TopDir, Dir),
    case dirp(FromD) of
	true ->
	    add_to_tar(Tar, FromD, filename:join(ToDir, Dir));
	_ ->
	    ok
    end.

%%
%% Add the priv dir if it exists.

add_priv(ADir, ToDir, Tar) ->
    Priv = filename:join(ADir, "priv"),
    case dirp(Priv) of
	true ->
	    add_to_tar(Tar, Priv, filename:join(ToDir, "priv"));
	_ ->
	    ok
    end.

add_erts_bin(Tar, Release, Flags) ->
    case get_flag(erts,Flags) of
	{erts,ErtsDir} ->
	    EVsn = Release#release.erts_vsn,
	    FromDir = filename:join([to_list(ErtsDir),
				     "erts-" ++ EVsn, "bin"]),
	    dirp(FromDir),
	    ToDir = filename:join("erts-" ++ EVsn, "bin"),
	    add_to_tar(Tar, FromDir, ToDir);
	_ ->
	    ok
    end.

%%______________________________________________________________________
%% Tar functions.

open_tar(TarName) ->
    case erl_tar:open(TarName, [write, compressed]) of
	{ok, Tar} ->
	    Tar;
	{error, Error} ->
	    throw({error,{tar_error, {open, TarName, Error}}})
    end.

close_tar(Tar) ->
    erl_tar:close(Tar).

del_tar(Tar, TarName) ->
    close_tar(Tar),
    del_file(TarName).

add_to_tar(Tar, FromFile, ToFile) ->
    case erl_tar:add(Tar, FromFile, ToFile, [compressed, dereference]) of
	ok -> ok;
	{error, Error} ->
	    throw({error, {tar_error, {add, FromFile, Error}}})
    end.

%%______________________________________________________________________    
%%______________________________________________________________________    
%% utilities!

make_set([]) -> [];
make_set([""|T]) -> % Ignore empty items.
    make_set(T);
make_set([H|T]) ->
    [H | [ Y || Y<- make_set(T),
		Y =/= H]].

to_list(A) when atom(A) -> atom_to_list(A);
to_list(L)              -> L.

mk_path(Path0) ->
    Path1 = map(fun(Dir) when atom(Dir) -> atom_to_list(Dir);
		   (Dir)                -> Dir
		end, Path0),
    Path = systools_lib:get_path(Path1),
    make_set(Path ++ code:get_path()).  % Use code path as well !

%% duplicates([Tuple]) -> List of pairs where 
%%    element(1, T1) == element(1, T2) and  where T1 and T2 are 
%%    taken from [Tuple]

duplicates(X) -> duplicates(keysort(1,X), []).

duplicates([H1,H2|T], L) -> 
    case {element(1,H1),element(1,H2)} of
	{X,X} -> duplicates([H2|T],[{H1,H2}|L]);
        _     -> duplicates([H2|T],L)
    end;
duplicates(_, L) -> L.

%% write_script(File, Term) -> ok %%   pretty prints Term on File 

write_script(File, Term) ->
    case file:open(File, write) of
	{ok, S} ->
	    io:format(S, "%% script generated at ~w ~w\n~p.\n",
		      [date(),time(),Term]),
	    file:close(S);
	{error, Reason} ->
	    io:format("Failed to open ~s for writing: ~s~n",
		      [File, file:format_error(Reason)]),
	    {error, Reason}
    end.

%% read_file(File, Path) -> {ok, Term, FullName} | {error, Error}
%% read a file and check the syntax, i.e. that it contains a correct
%% Erlang term.

read_file(File, Path) ->
    case file:path_open(Path, File, read) of
	{ok, Stream, FullName} ->
%	    io:format("~p located in: ~p\n", [File, FullName]),
	    Return = case systools_lib:read_term_from_stream(Stream, File) of
			 {ok, Term} ->
			     {ok, Term, FullName};
			 Other ->
			     Other
		     end,
	    file:close(Stream),
	    Return;
	Other ->
%	    io:format("Cannot locate file: File ~p, Path ~p\n", [File, Path]),
	    {error, {not_found, File}}
    end.

del_file(File) -> file:delete(File).

dirp(Dir) ->
    case file:read_file_info(Dir) of
	{ok, FileInfo} -> FileInfo#file_info.type == directory;
	_ ->              false
    end.

%% Create the include path. Assumptions about the code path is done
%% and an include directory is added.
%% Add the official include dir for each found application first in path !!
%% If .../ebin exists in a path an .../include directory is assumed to
%% exist at the same level. If .../ebin is not existing the .../include
%% directory is assumed anyhow.
%% Local includes are added for each application later on.

create_include_path(Appls, Path) ->
    FoundAppDirs = map(fun({_,A}) -> A#application.dir end, Appls),
    map(fun(Dir) ->
		case reverse(filename:split(Dir)) of
		    ["ebin"|D] ->
			filename:join(reverse(D) ++ ["include"]);
		    _ ->
			filename:join(Dir, "include")
		end
	end,
	FoundAppDirs ++ no_dupl(Path, FoundAppDirs)).

no_dupl([Dir|Path], FoundAppDirs) ->
    case member(Dir, FoundAppDirs) of
	true ->
	    no_dupl(Path, FoundAppDirs);
	_ ->
	    [Dir|no_dupl(Path, FoundAppDirs)]
    end;
no_dupl([], _) ->
    [].

is_app_type(permanent) -> true;
is_app_type(transient) -> true;
is_app_type(temporary) -> true;
is_app_type(none) -> true;
is_app_type(load) -> true;
is_app_type(_) -> false.

% check if a term is a string.

string_p([H|T]) when integer(H), H >= $ , H < 255 ->
    string_p(T);
string_p([$\n|T]) -> string_p(T);
string_p([$\r|T]) -> string_p(T);
string_p([$\t|T]) -> string_p(T);
string_p([$\v|T]) -> string_p(T);
string_p([$\b|T]) -> string_p(T);
string_p([$\f|T]) -> string_p(T);
string_p([$\e|T]) -> string_p(T);
string_p([]) -> true;
string_p(_) ->  false.

% check if a term is a list of two tuples with the first
% element as an atom.

t_list_p([{A,_}|T]) when atom(A) -> t_list_p(T);
t_list_p([])                     -> true;
t_list_p(_)                      -> false.

% check if a term is a list of atoms or two-tuples with the first
% element as an atom.

mod_list_p([{A,_}|T]) when atom(A) -> mod_list_p(T);
mod_list_p([A|T]) when atom(A)     -> mod_list_p(T);
mod_list_p([])                     -> true;
mod_list_p(_)                      -> false.

% check if a term is a list of atoms.

a_list_p([A|T]) when atom(A) -> a_list_p(T);
a_list_p([])                 -> true;
a_list_p(_)                  -> false.

%% Get a key-value tuple flag from a list.

get_flag(F,[{F,D}|_]) -> {F,D};
get_flag(F,[_|Fs])    -> get_flag(F,Fs);
get_flag(_,_)         -> false.





%% Check Options for make_script
check_args_script(Args) ->
    cas(Args, {undef, undef, undef, undef, undef, undef, undef, undef, []}). 

cas([], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X}) ->
    {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X};
%%% path ---------------------------------------------------------------------------
cas([{path, P} | Args], {Path, Sil, Loc, Test, Var, Mach, 
			 Xref, XrefApps, X}) when list(P) -> 
    case check_path(P) of
	ok ->
	    cas(Args, {P, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X});
	error ->
	    cas(Args, {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X++[{path,P}]})
    end;
%%% silent -------------------------------------------------------------------------
cas([silent | Args], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X}) ->
    cas(Args, {Path, silent, Loc, Test, Var, Mach, Xref, XrefApps, X});
%%% local --------------------------------------------------------------------------
cas([local | Args], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X}) ->
    cas(Args, {Path, Sil, local, Test, Var, Mach, Xref, XrefApps, X});
%%% no_module_tests ----------------------------------------------------------------
cas([no_module_tests | Args], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X}) ->
    cas(Args, {Path, Sil, Loc, no_module_tests, Var, Mach, 
		     Xref, XrefApps, X});
%%% variables ----------------------------------------------------------------------
cas([{variables, V} | Args], {Path, Sil, Loc, Test, Var, Mach, 
				 Xref, XrefApps, X}) when list(V) ->
    case check_vars(V) of
	ok ->
	    cas(Args, {Path, Sil, Loc, Test, V, Mach, Xref, XrefApps, X});
	error ->
	    cas(Args, {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X++[{variables, V}]})
    end;
%%% machine ------------------------------------------------------------------------
cas([{machine, M} | Args], {Path, Sil, Loc, Test, Var, Mach, 
			    Xref, XrefApps, X}) when atom(M) ->
    cas(Args, {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X});
%%% exref --------------------------------------------------------------------------
cas([exref | Args], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X})  ->
    cas(Args, {Path, Sil, Loc, Test, Var, Mach, exref, XrefApps, X});
%%% exref Apps ---------------------------------------------------------------------
cas([{exref, Apps} | Args], {Path, Sil, Loc, Test, Var, Mach, 
			     Xref, XrefApps, X}) when list(Apps) ->
    case check_apps(Apps) of 
	ok ->
	    cas(Args, {Path, Sil, Loc, Test, Var, Mach, 
			     Xref, Apps, X});
	error ->
	    cas(Args, {Path, Sil, Loc, Test, Var, Mach, 
			     Xref, XrefApps, X++[{exref, Apps}]})
    end;
%%% otp_build (secret, not documented) ---------------------------------------------
cas([otp_build | Args], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X}) ->
    cas(Args, {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X});
%%% ERROR --------------------------------------------------------------------------
cas([Y | Args], {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X}) ->
    cas(Args, {Path, Sil, Loc, Test, Var, Mach, Xref, XrefApps, X++[Y]}).



%% Check Options for make_tar
check_args_tar(Args) ->
    cat(Args, {undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, []}). 

cat([], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X}) ->
    {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X};
%%% path ---------------------------------------------------------------------------
cat([{path, P} | Args], {Path, Sil, Dirs, Erts, Test, 
			 Var, VarTar, Mach, Xref, XrefApps, X}) when list(P) -> 
    case check_path(P) of
	ok ->
	    cat(Args, {P, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X});
	error ->
	    cat(Args, {Path, Sil, Dirs, Erts, Test, 
		       Var, VarTar, Mach, Xref, XrefApps, X++[{path,P}]})
    end;
%%% silent -------------------------------------------------------------------------
cat([silent | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X}) ->
    cat(Args, {Path, silent, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X});
%%% dirs ---------------------------------------------------------------------------
cat([{dirs, D} | Args], {Path, Sil, Dirs, Erts, Test, 
			    Var, VarTar, Mach, Xref, XrefApps, X}) ->
    case check_dirs(D) of
	ok ->
	    cat(Args, {Path, Sil, D, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X});
	error ->
	    cat(Args, {Path, Sil, Dirs, Erts, Test, 
		       Var, VarTar, Mach, Xref, XrefApps, X++[{dirs, D}]})
    end;
%%% erts ---------------------------------------------------------------------------
cat([{erts, E} | Args], {Path, Sil, Dirs, Erts, Test, 
			 Var, VarTar, Mach, Xref, XrefApps, X}) when list(E)->
    cat(Args, {Path, Sil, Dirs, E, Test, Var, VarTar, Mach, Xref, XrefApps, X});
%%% no_module_tests ----------------------------------------------------------------
cat([no_module_tests | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X}) ->
    cat(Args, {Path, Sil, Dirs, Erts, no_module_tests, Var, VarTar, Mach, 
		     Xref, XrefApps, X});
%%% variables ----------------------------------------------------------------------
cat([{variables, V} | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X}) when list(V) ->
    case check_vars(V) of
	ok ->
	    cat(Args, {Path, Sil, Dirs, Erts, Test, V, VarTar, Mach, Xref, XrefApps, X});
	error ->
	    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, 
			     Xref, XrefApps, X++[{variables, V}]})
    end;
%%% var_tar ------------------------------------------------------------------------
cat([{var_tar, VT} | Args], {Path, Sil, Dirs, Erts, Test, 
			    Var, VarTar, Mach, Xref, XrefApps, X}) when VT == include ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, include, Mach, Xref, XrefApps, X});
cat([{var_tar, VT} | Args], {Path, Sil, Dirs, Erts, Test, 
			    Var, VarTar, Mach, Xref, XrefApps, X}) when VT == ownfile ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, ownfile, Mach, Xref, XrefApps, X});
cat([{var_tar, VT} | Args], {Path, Sil, Dirs, Erts, Test, 
			    Var, VarTar, Mach, Xref, XrefApps, X}) when VT == omit ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, omit, Mach, Xref, XrefApps, X});
%%% machine ------------------------------------------------------------------------
cat([{machine, M} | Args], {Path, Sil, Dirs, Erts, Test, 
			    Var, VarTar, Mach, Xref, XrefApps, X}) when atom(M) ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X});
%%% exref --------------------------------------------------------------------------
cat([exref | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X})  ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, exref, XrefApps, X});
%%% exref Apps ---------------------------------------------------------------------
cat([{exref, Apps} | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X}) when list(Apps) ->
    case check_apps(Apps) of 
	ok ->
	    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, 
			     Xref, Apps, X});
	error ->
	    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, 
			     Xref, XrefApps, X++[{exref, Apps}]})
    end;
%%% otp_build (secret, not documented) ---------------------------------------------
cat([otp_build | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X})  ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X});
%%% ERROR --------------------------------------------------------------------------
cat([Y | Args], {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X}) ->
    cat(Args, {Path, Sil, Dirs, Erts, Test, Var, VarTar, Mach, Xref, XrefApps, X++[Y]}).



check_path([]) ->
    ok;
check_path([H|T]) when list(H) ->
    check_path(T);
check_path([H|T]) ->
    error.


check_dirs([]) ->
    ok;
check_dirs([H|T]) when atom(H) ->
    check_dirs(T);
check_dirs([H|T]) ->
    error.



check_vars([]) ->
    ok;
check_vars([{Name, Dir} | T]) ->
    case {Name, Dir} of
	_ when atom(name), list(Dir) ->
	    check_vars(T);
	_ when list(name), list(Dir) ->
	    check_vars(T);
	_ ->
	    error
    end;
check_vars(_) ->
    error.



check_apps([]) ->
    ok;
check_apps([H|T]) when atom(H) ->
    check_apps(T);
check_apps(_) ->
    error.






%% Format error

format_error(badly_formatted_release) ->
    io_lib:format("Syntax error in the release file~n",[]);
format_error({illegal_name, Name}) ->
    io_lib:format("Illegal name (~p) in the release file~n",[Name]);
format_error({illegal_form, Form}) ->
    io_lib:format("Illegal tag in the release file: ~p~n",[Form]);
format_error({missing_parameter,Par}) ->
    io_lib:format("Missing parameter (~p) in the release file~n",[Par]);
format_error({illegal_applications,Names}) ->
    io_lib:format("Illegal applications in the release file: ~p~n",
		  [Names]);
format_error({missing_mandatory_app,Names}) ->
    io_lib:format("Mandatory applications (~p) must be specified in the release file~n",
		  [Names]);
format_error({duplicate_register,Dups}) ->
    io_lib:format("Duplicated register names: ~n~s",
		  [map(fun({{Reg,App1,_,_},{Reg,App2,_,_}}) ->
			       io_lib:format("\t~p registered in ~p and ~p~n",
					     [Reg,App1,App2])
		       end, Dups)]);
format_error({undefined_applications,Apps}) ->
    io_lib:format("Undefined applications: ~p~n",[Apps]);
format_error({duplicate_modules,Dups}) ->
    io_lib:format("Duplicated modules: ~n~s",
		  [map(fun({{Mod,_,App1,_,_},{Mod,_,App2,_,_}}) ->
			       io_lib:format("\t~p specified in ~p and ~p~n",
					     [Mod,App1,App2])
		       end, Dups)]);
format_error({included_and_used, Dups}) ->
    io_lib:format("Applications both used and included: ~p~n",[Dups]);
format_error({duplicate_include, Dups}) ->
    io_lib:format("Duplicated application included: ~n~s",
		  [map(fun({{Name,App1,_,_},{Name,App2,_,_}}) ->
			       io_lib:format("\t~p included in ~p and ~p~n",
					     [Name,App1,App2])
		       end, Dups)]);
format_error({modules,ModErrs}) ->
    format_errors(ModErrs);
format_error({circular_dependencies,Apps}) ->
    io_lib:format("Circular dependencies among applications: ~p~n",[Apps]);
format_error({not_found,File}) ->
    io_lib:format("File not found: ~p~n",[File]);
format_error({parse,File,{Line,Mod,What}}) ->
    Str = Mod:format_error(What),
    io_lib:format("~s:~p: ~s\n",[File, Line, Str]);
format_error({read,File}) ->
    io_lib:format("Cannot read ~p~n",[File]);
format_error({open,File,Error}) ->
    io_lib:format("Cannot open ~p - ~p~n",[File,Error]);
format_error({tar_error,What}) ->
    form_tar_err(What);
format_error(ListOfErrors) when list(ListOfErrors) ->
    format_errors(ListOfErrors);
format_error(E) -> io_lib:format("~p~n",[E]).

format_errors(ListOfErrors) ->
    map(fun({error,E}) -> form_err(E);
	   (E)         -> form_err(E)
	end, ListOfErrors).

form_err({bad_application_name,{Name,Found}}) ->
    io_lib:format("~p: Mismatched application id: ~p~n",[Name,Found]);
form_err({error_reading, {Name, What}}) ->
    io_lib:format("~p: ~s~n",[Name,form_reading(What)]);
form_err({module_not_found,{Mod,_,App,_,_}}) ->
    io_lib:format("~p: Module (~p) not found~n",[App,Mod]);
form_err({{vsn_diff,File},{Mod,Vsn,App,_,_}}) ->
    io_lib:format("~p: Module (~p) version (~p) differs in file ~p~n",
		  [App,Mod,Vsn,File]);
form_err({error_add_appl, {Name, {tar_error, What}}}) ->
    io_lib:format("~p: ~s~n",[Name,form_tar_err(What)]);
form_err(E) ->
    io_lib:format("~p~n",[E]).

form_reading({not_found,File}) ->
    io_lib:format("File not found: ~p~n",[File]);
form_reading({application_vsn, {Name,Vsn}}) ->
    io_lib:format("Application ~s with version ~p not found~n",[Name, Vsn]);
form_reading({parse,File,{Line,Mod,What}}) ->
    Str = Mod:format_error(What),
    io_lib:format("~s:~p: ~s\n",[File, Line, Str]);
form_reading({read,File}) ->
    io_lib:format("Cannot read ~p~n",[File]);
form_reading({{bad_param, P},_}) ->
    io_lib:format("Bad parameter in .app file: ~p~n",[P]);
form_reading({{missing_param,P},_}) ->
    io_lib:format("Missing parameter in .app file: ~p~n",[P]);
form_reading({badly_formatted_application,_}) ->
    io_lib:format("Syntax error in .app file~n",[]);
form_reading({override_include,Apps}) ->
    io_lib:format("Tried to include not (in .app file) specified applications: ~p~n",
		  [Apps]);
form_reading({no_valid_version, {{_, SVsn}, {_, File, FVsn}}}) ->
    io_lib:format("No valid version (~p) of .app file found. Found file ~p with version ~p~n", 
		  [SVsn, File, FVsn]);
form_reading({parse_error, {File, Line, Error}}) ->
    io_lib:format("Parse error in file: ~p.  Line: ~p  Error: ~p; ~n", [File, Line, Error]);
form_reading(W) ->
    io_lib:format("~p~n",[W]).

form_tar_err({open, File, Error}) ->
    io_lib:format("Cannot open tar file ~s - ~p~n",
		  [File, erl_tar:format_error(Error)]);
form_tar_err({add, File, Error}) ->
    io_lib:format("Cannot add file ~s to tar file - ~s~n",
		  [File, erl_tar:format_error(Error)]).

%% Format warning

format_warning(Warnings) ->
    map(fun({warning,W}) -> form_warn(W) end, Warnings).

form_warn({source_not_found,{Mod,_,App,_,_}}) ->
    io_lib:format("*WARNING* ~p: Source code not found: ~p.erl~n",
		  [App,Mod]);
form_warn({{could_not_open, File},{_,_,App,_,_}}) ->
    io_lib:format("*WARNING* ~p: Could not open file: ~p~n",
		  [App,File]);
form_warn({{include_not_found, File, IncF},{_,_,App,_,_}}) ->
    io_lib:format("*WARNING* ~p: Include (~p) file not found: ~p~n",
		  [App,IncF,File]);
form_warn({{parse_error, File},{_,_,App,_,_}}) ->
    io_lib:format("*WARNING* ~p: Parse error: ~p~n",
		  [App,File]);
form_warn({{obj_out_of_date, _},{Mod,_,App,_,_}}) ->
    io_lib:format("*WARNING* ~p: Object code (~p) out of date~n",[App,Mod]);
form_warn({exref_undef, Undefd}) ->
    map(fun({undefined,{M,F,A},Called}) ->
		MCall = append(map(fun({called_by,{_,ML,MM,MF,MA}}) ->
					   io_lib:format("\t~p:~p/~p at line ~p~n",
							 [MM,MF,MA,ML]);
				      (_) ->
					   []
				   end, Called)),
		io_lib:format("*WARNING* Undefined function ~p:~p/~p called by:~n~s",
			      [M,F,A,MCall]);
		
	   (_) ->
		[]
	end, Undefd);
form_warn({exref_app_rel, AppRels}) ->
    map(fun({App1, App2}) ->
		io_lib:format("*WARNING* ~p: Calls functions in not "
			      "exref'ed application ~p~n", [App1, App2])
	end, AppRels);
form_warn(What) ->
    io_lib:format("*WARNING* ~p~n",[What]).
		       