%% This is a wrapper for hipe_vectors
%%  It shifts all elements up one step so that key 0 can be used.

-module(hipe_vectors_wrapper).
-export([empty/2,set/3,get/2,init/1,vector_to_list/1, init/2,vsize/1, list/1]).


empty(Size ,InitialElement) -> hipe_vectors:empty(Size ,InitialElement).
set( Vector, Element, Value) -> hipe_vectors:set( Vector, Element+1, Value).
get( Vector, Element ) -> hipe_vectors:get( Vector, Element+1 ).
init(Size) -> hipe_vectors:init(Size).
vector_to_list(Vector) -> hipe_vectors:vector_to_list(Vector).
init(Size,Val) -> hipe_vectors:init(Size,Val).
vsize(Vector) ->  hipe_vectors:vsize(Vector).
list(Vector) ->  [{N-1,V} || {N,V} <- hipe_vectors:list(Vector)].
  