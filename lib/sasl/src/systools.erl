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
-module(systools).

%% Usage:
%%    systools:make_script("RelName")     
%%                        Make a boot file from RelName.rel.
%%                        Generates RelName.{script,boot}
%%    systools:make_tar("RelName")     
%%                        Make a release package from RelName.rel.
%%                        Generates RelName.tar,Z
%%    systools:script2boot(File)
%%                        File.script -> File.boot
%%    systools:mk_relup("Target", ["UpFromRel"...], ["DownToRel"...], Opts)
%%			  Gather all relup scripts to the relup file
%%

-export([script2boot/1, script2boot/3, compile_rel/3,
	 make_script/1, make_script/2,
	 make_tar/1, make_tar/2,
	 make_relup/3, make_relup/4]).

-include("erl_compile.hrl").

%%% The behaviour_info functions have been moved to erl_internal in stdlib.

%%-----------------------------------------------------------------
%% Options is a list of {path, Path} | silent | local where path sets
%% the search path, silent supresses error message printing on console,
%% local generates a script with references to the directories there
%% the applications are found.
%%-----------------------------------------------------------------
make_script(RelName) -> make_script(RelName, []).

make_script(RelName, Opt) ->
    systools_make:make_script(RelName, Opt).

%%-----------------------------------------------------------------
%% Options is a list of {path, Path} | silent |
%%    {dirs, [src,include,examples,..]} | {erts, ErtsDir} where path
%% sets the search path, silent supresses error message printing on console,
%% dirs includes the specified directories (per application) in the
%% release package and erts specifies that the erts-Vsn/bin directory
%% should be included in the release package and there it can be found.
%%-----------------------------------------------------------------
make_tar(RelName) -> make_tar(RelName, []).

make_tar(RelName, Opt) ->
    systools_make:make_tar(RelName, Opt).

%%-----------------------------------------------------------------
%% Create a binary form of a boot script.
%%-----------------------------------------------------------------
script2boot(File) ->
    case systools_lib:file_term2binary(File ++ ".script", File ++ ".boot") of
	{error,Error} ->
	    io:format(systools_make:format_error(Error)),
	    error;
	_ ->
	    ok
    end.

script2boot(File, Output0, _Opt) ->
    Input = File++".script",
    Output = Output0++".boot",
    case systools_lib:file_term2binary(Input, Output) of
	{error,Error} ->
	    io:format(systools_make:format_error(Error)),
	    error;
	_ ->
	    ok
    end.

%%-----------------------------------------------------------------
%% Options is a list of {path, Path} | silent | noexec where path sets
%% search path, silent supresses error message printing on console,
%% noexec supresses writing the output "relup" file
%%-----------------------------------------------------------------
make_relup(ReleaseName, UpNameList, DownNameList) ->
    systools_relup:mk_relup(ReleaseName, UpNameList, DownNameList, []).
make_relup(ReleaseName, UpNameList, DownNameList, Opts) ->
    systools_relup:mk_relup(ReleaseName, UpNameList, DownNameList, Opts).

%%-----------------------------------------------------------------
%% Interface for erl_compile to compile .rel files.
%%-----------------------------------------------------------------
compile_rel(Input, Output, Options) ->
    systools_make:make_script(Input, Output, translate_options(Options)).

translate_options(Opts) ->
    [{path, Opts#options.includes}|Opts#options.specific].