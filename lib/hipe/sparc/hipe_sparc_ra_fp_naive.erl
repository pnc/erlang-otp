%% -*- erlang-indent-level: 2 -*-
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright (c) 2000 by Erik Johansson.  
%% Time-stamp: <02/02/26 09:30:15 happi>
%% ====================================================================
%%  Filename : 	hipe_sparc_ra_fp_naive.erl
%%  Module   :	hipe_sparc_ra_fp_naive
%%  Purpose  :  Provides a silly register allocation to be used as
%%               baseline for benchmarking register allocators.
%%  Notes    : 
%%  History  :	* 2000-08-21 Erik Johansson (happi@csd.uu.se): 
%%               Created.
%%  CVS      :
%%              $Author: kostis $
%%              $Date: 2002/05/13 11:29:54 $
%%              $Revision: 1.2 $
%% ====================================================================
%%  Exports  :
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(hipe_sparc_ra_fp_naive).
-export([alloc/2]).
%-define(HIPE_INSTRUMENT_COMPILER, true). %% Turn on instrumentation.
-include("../main/hipe.hrl").

alloc(SparcCfg, _Options) ->
  Map = fp_alloc(SparcCfg),
  %% io:format("ListMap:~w\n",[Map]),
  TempMap = hipe_temp_map:cols2tuple(Map, hipe_sparc_specific),
  %%  io:format("Map:~w\n",[TempMap]),
  TempMap.


fp_alloc(Cfg) ->
  {_,Last} = hipe_sparc_cfg:var_range(Cfg),
  Map = hipe_vectors:empty(Last+1,undef),
  Code = hipe_sparc:sparc_code(hipe_sparc_cfg:linearize(Cfg)),
  {NewMap, _SpillPos} = traverse(Code,Map),
  [{T-1,Pos} || {T,Pos} <- hipe_vectors:list(NewMap),
		Pos =/= undef].


traverse(Code, Map) ->
  lists:foldl(fun map/2, {Map,0}, Code).


map(I,{Map, Pos}) ->
  {Map1, Pos1} = map(hipe_sparc:fp_reg_defines(I), Map, Pos),
  map(hipe_sparc:fp_reg_uses(I), Map1, Pos1).

map(Temps, Map, Pos) ->
  lists:foldl(fun map_temp/2, {Map,Pos}, Temps).
   
map_temp(T,{Map,Pos}) ->

  RealTemp = hipe_sparc:fpreg_nr(T),
  Temp = RealTemp+1,

  case hipe_vectors:get(Map,Temp) of
    undef ->
      {hipe_vectors:set(Map,Temp,
			    {fp_reg,Pos}),
       Pos +2};
    _ ->
      {Map,Pos}
  end.

