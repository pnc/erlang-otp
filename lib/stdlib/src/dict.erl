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

%% We use the dynamic hashing techniques by Per-�ke Larsson as
%% described in "The Design and Implementation of Dynamic Hashing for
%% Sets and Tables in Icon" by Griswold and Townsend.  Much of the
%% terminology comes from that paper as well.
%%
%% The segments are all of the same fixed size and we just keep
%% increasing the size of the top tuple as the table grows.  At the
%% end of the segments tuple we keep an empty segment which we use
%% when we expand the segments.  The segments are expanded by doubling
%% every time n reaches maxn instead of increasing the tuple one
%% element at a time.  It is easier and does not seem detrimental to
%% speed.  The same applies when contracting the segments.
%%
%% Note that as the order of the keys is undefined we may freely
%% reorder keys within in a bucket.

-module(dict).

%% Standard interface.
-export([new/0,is_key/2,to_list/1,from_list/1,size/1]).
-export([fetch/2,find/2,fetch_keys/1,erase/2]).
-export([store/3,append/3,append_list/3,update/3,update/4,update_counter/3]).
-export([fold/3,map/2,filter/2,merge/3]).

%% Depreciated interface.
-export([dict_to_list/1,list_to_dict/1]).

%% Low-level interface.
%%-export([get_slot/2,get_bucket/2,on_bucket/3,fold_dict/3,
%%	 maybe_expand/2,maybe_contract/2]).

%-define(seg_size, 2).
%-define(max_seg, 32).
%-define(expand_load, 2).
%-define(contract_load, 1).
-define(seg_size, 16).
-define(max_seg, 32).
-define(expand_load, 5).
-define(contract_load, 3).

%% Define a hashtable.  The default values are the standard ones.
-record(dict,
	{size=0,				%Number of elements
	 n=?seg_size,				%Number of active slots
	 maxn=?seg_size,			%Maximum slots
	 bso=?seg_size div 2,			%Buddy slot offset
	 exp_size=?seg_size * ?expand_load,	%Size to expand at
	 con_size=?seg_size * ?contract_load,	%Size to contract at
	 empty,					%Empty segment
	 segs					%Segments
	}).

-define(kv(K,V), [K|V]).			%Key-Value pair format
%%-define(kv(K,V), {K,V}).			%Key-Value pair format

%% new() -> Table.

new() ->
    Empty = mk_seg(?seg_size),
    #dict{empty=Empty,segs={Empty}}.

%% is_key(Key, Dictionary) -> bool().

is_key(Key, D) ->
    Slot = get_slot(D, Key),
    Bkt = get_bucket(D, Slot),
    find_key(Key, Bkt).

find_key(K, [?kv(K,Val)|Bkt]) -> true;
find_key(K, [_|Bkt]) -> find_val(K, Bkt);
find_key(K, []) -> false.

%% to_list(Dictionary) -> [{Key,Value}].

to_list(D) ->
    fold(fun (Key, Val, List) -> [{Key,Val}|List] end, [], D).

%% from_list([{Key,Value}]) -> Dictionary.

from_list(L) ->
    lists:foldl(fun ({K,V}, D) -> store(K, V, D) end, new(), L).

%% size(Dictionary) -> int().

size(D) -> D#dict.size. 

%% fetch(Key, Dictionary) -> Value.

fetch(Key, D) ->
    Slot = get_slot(D, Key),
    Bkt = get_bucket(D, Slot),
    fetch_val(Key, Bkt).

fetch_val(K, [?kv(K,Val)|Bkt]) -> Val;
fetch_val(K, [_|Bkt]) -> fetch_val(K, Bkt).

%% find(Key, Dictionary) -> {ok,Value} | error.

find(Key, D) ->
    Slot = get_slot(D, Key),
    Bkt = get_bucket(D, Slot),
    find_val(Key, Bkt).

find_val(K, [?kv(K,Val)|Bkt]) -> {ok,Val};
find_val(K, [_|Bkt]) -> find_val(K, Bkt);
find_val(K, []) -> error.

%% fetch_keys(Dictionary) -> [Key].

fetch_keys(D) ->
    fold(fun (Key, Val, Keys) -> [Key|Keys] end, [], D).

%% erase(Key, Dictionary) -> NewDictionary.
%%  Erase all elements with key Key.

erase(Key, D0) -> 
    Slot = get_slot(D0, Key),
    {D1,Dc} = on_bucket(fun (B0) -> erase_key(Key, B0) end,
			D0, Slot),
    maybe_contract(D1, Dc).

erase_key(Key, [?kv(Key,Val)|Bkt]) -> {Bkt,1};
erase_key(Key, [E|Bkt0]) ->
    {Bkt1,Dc} = erase_key(Key, Bkt0),
    {[E|Bkt1],Dc};
erase_key(Key, []) -> {[],0}.

%% store(Key, Value, Dictionary) -> Dictionary.

store(Key, Val, D0) ->
    Slot = get_slot(D0, Key),
    {D1,Ic} = on_bucket(fun (B0) -> store_bkt_val(Key, Val, B0) end,
			D0, Slot),
    maybe_expand(D1, Ic).

%% store_bkt_val(Key, Val, Bucket) -> {NewBucket,PutCount}.

store_bkt_val(Key, New, [?kv(Key,Old)|Bkt]) -> {[?kv(Key,New)|Bkt],0};
store_bkt_val(Key, New, [Other|Bkt0]) ->
    {Bkt1,Ic} = store_bkt_val(Key, New, Bkt0),
    {[Other|Bkt1],Ic};
store_bkt_val(Key, New, []) -> {[?kv(Key,New)],1}.

%% append(Key, Value, Dictionary) -> Dictionary.

append(Key, Val, D0) ->
    Slot = get_slot(D0, Key),
    {D1,Ic} = on_bucket(fun (B0) -> append_bkt(Key, Val, B0) end,
			D0, Slot),
    maybe_expand(D1, Ic).

%% append_bkt(Key, Val, Bucket) -> {NewBucket,PutCount}.

append_bkt(Key, Val, [?kv(Key,Bag)|Bkt]) -> {[?kv(Key,Bag ++ [Val])|Bkt],0};
append_bkt(Key, Val, [Other|Bkt0]) ->
    {Bkt1,Ic} = append_bkt(Key, Val, Bkt0),
    {[Other|Bkt1],Ic};
append_bkt(Key, Val, []) -> {[?kv(Key,[Val])],1}.

%% append_list(Key, List, Dictionary) -> Dictionary.

append_list(Key, L, D0) ->
    Slot = get_slot(D0, Key),
    {D1,Ic} = on_bucket(fun (B0) -> app_list_bkt(Key, L, B0) end,
			D0, Slot),
    maybe_expand(D1, Ic).

%% app_list_bkt(Key, L, Bucket) -> {NewBucket,PutCount}.

app_list_bkt(Key, L, [?kv(Key,Bag)|Bkt]) -> {[?kv(Key,Bag ++ L)|Bkt],0};
app_list_bkt(Key, L, [Other|Bkt0]) ->
    {Bkt1,Ic} = app_list_bkt(Key, L, Bkt0),
    {[Other|Bkt1],Ic};
app_list_bkt(Key, L, []) -> {[?kv(Key,L)],1}.

% %% first_key(Table) -> {ok,Key} | error.
% %%  Find the "first" key in a Table.

% first_key(T) ->
%     case next_bucket(T, 1) of
% 	[?kv(K,Val)|Bkt] -> {ok,K};
% 	[] -> error				%No elements
%     end.

% next_bucket(T, Slot) when Slot > T#dict.n -> [];
% next_bucket(T, Slot) ->
%     case get_bucket(T, Slot) of
% 	[] -> next_bucket(T, Slot+1);		%Empty bucket
% 	B -> B
%     end.

%% next_key(Table, Key) -> {ok,NextKey} | error.

% next_key(T, Key) ->
%     Slot = get_slot(T, Key),
%     B = get_bucket(T, Slot),
%     %% Find a bucket with something in it.
%     Bkt = case bucket_after_key(Key, B) of
% 	      no_key -> exit(badarg);
% 	      [] -> next_bucket(T, Slot+1);
% 	      Rest -> Rest
% 	  end,
%     case Bkt of
% 	[?kv(Next,Val)|_] -> {ok,Next};
% 	[] -> error				%We have reached the end!
%     end.

% bucket_after_key(Key, [?kv(Key,Val)|Bkt]) -> Bkt;
% bucket_after_key(Key, [Other|Bkt]) ->
%     bucket_after_key(Key, Bkt);
% bucket_after_key(Key, []) -> no_key.		%Key not found!

%% on_key(Fun, Key, Dictionary) -> Dictionary.

% on_key(F, Key, D0) ->
%     Slot = get_slot(D0, Key),
%     {D1,Dc} = on_bucket(fun (B0) -> on_key_bkt(Key, F, B0) end,
% 			D0, Slot),
%     maybe_contract(D1, Dc).

% on_key_bkt(Key, F, [?kv(Key,Val)|Bkt]) ->
%     case F(Val) of
% 	{ok,New} -> {[?kv(Key,New)|Bkt],0}; 
% 	erase -> {Bkt,1}
%     end;
% on_key_bkt(Key, F, [Other|Bkt0]) ->
%     {Bkt1,Dc} = on_key_bkt(Key, F, Bkt0),
%     {[Other|Bkt1],Dc}.

%% update(Key, Fun, Dictionary) -> Dictionary.

update(Key, F, D0) ->
    Slot = get_slot(D0, Key),
    {D1,Uv} = on_bucket(fun (B0) -> update_bkt(Key, F, B0) end,
			D0, Slot),
    D1.

update_bkt(Key, F, [?kv(Key,Val)|Bkt]) ->
    Upd = F(Val),
    {[?kv(Key,Upd)|Bkt],Upd};
update_bkt(Key, F, [Other|Bkt0]) ->
    {Bkt1,Upd} = update_bkt(Key, F, Bkt0),
    {[Other|Bkt1],Upd}.

%% update(Key, Fun, Init, Dictionary) -> Dictionary.

update(Key, F, Init, D0) ->
    Slot = get_slot(D0, Key),
    {D1,Ic} = on_bucket(fun (B0) -> update_bkt(Key, F, Init, B0) end,
			D0, Slot),
    maybe_expand(D1, Ic).

update_bkt(Key, F, I, [?kv(Key,Val)|Bkt]) ->
    {[?kv(Key,F(Val))|Bkt],0};
update_bkt(Key, F, I, [Other|Bkt0]) ->
    {Bkt1,Ic} = update_bkt(Key, F, I, Bkt0),
    {[Other|Bkt1],Ic};
update_bkt(Key, F, I, []) -> {[?kv(Key,I)],1}.

%% update_counter(Key, Incr, Dictionary) -> Dictionary.

update_counter(Key, Incr, D0) ->
    Slot = get_slot(D0, Key),
    {D1,Ic} = on_bucket(fun (B0) -> counter_bkt(Key, Incr, B0) end,
			D0, Slot),
    maybe_expand(D1, Ic).

counter_bkt(Key, I, [?kv(Key,Val)|Bkt]) ->
    {[?kv(Key,Val+I)|Bkt],0};
counter_bkt(Key, I, [Other|Bkt0]) ->
    {Bkt1,Ic} = counter_bkt(Key, I, Bkt0),
    {[Other|Bkt1],Ic};
counter_bkt(Key, I, []) -> {[?kv(Key,I)],1}.

%% foldFold(Fun, Accumulator, Dictionary) -> Accumulator.
%%  Fold function Fun over all "bags" in Table and return Accumulator.

fold(F, Acc, D) -> fold_dict(F, Acc, D).

%% map(MapFun, Dictionary) -> Dictionary.

map(F, D) -> map_dict(F, D).

%% filter(FilterFun, Dictionary) -> Dictionary.

filter(F, D) -> filter_dict(F, D).

%% merge(MergeFun, Dictionary, Dictionary) -> Dictionary.

merge(F, D1, D2) ->
    fold_dict(fun (K, V1, D) ->
		      update(K, fun (V2) -> F(K, V1, V2) end, V1, D)
	      end, D2, D1).

%% Depreciated interface.

%% dict_to_list(Dictionary) -> [{Key,Value}].

dict_to_list(D) -> to_list(D).

%% list_to_dict([{Key,Value}]) -> Dictionary.

list_to_dict(L) -> from_list(L).

%% get_slot(Hashdb, Key) -> Slot.
%%  Get the slot.  First hash on the new range, if we hit a bucket
%%  which has not been split use the unsplit buddy bucket.

get_slot(T, Key) ->
    H = erlang:hash(Key, T#dict.maxn),
    if
	H > T#dict.n -> H - T#dict.bso;
	true -> H
    end.

%% get_bucket(Hashdb, Slot) -> Bucket.

get_bucket(T, Slot) -> get_bucket_s(T#dict.segs, Slot).

%% on_bucket(Fun, Hashdb, Slot) -> {NewHashDb,Result}.
%%  Apply Fun to the bucket in Slot and replace the returned bucket.

on_bucket(F, T, Slot) ->
    SegI = ((Slot-1) div ?seg_size) + 1,
    BktI = ((Slot-1) rem ?seg_size) + 1,
    Segs = T#dict.segs,
    Seg = element(SegI, Segs),
    B0 = element(BktI, Seg),
    {B1,Res} = F(B0),				%Op on the bucket.
    {T#dict{segs=setelement(SegI, Segs, setelement(BktI, Seg, B1))},Res}.

%% fold_dict(Fun, Acc, Dictionary) -> Dictionary.
%% map_dict(Fun, Dictionary) -> Dictionary.
%% filter_dict(Fun, Dictionary) -> Dictionary.

%%  Work functions for fold, map and filter operations.  These
%%  traverse the hash structure rebuilding as necessary.  Note we
%%  could have implemented map and filter using fold but these are be
%%  faster.  We hope!

fold_dict(F, Acc, D) ->
    Segs = D#dict.segs,
    fold_segs(F, Acc, Segs, size(Segs)).

fold_segs(F, Acc, Segs, I) when I >= 1 ->
    Seg = element(I, Segs),
    fold_segs(F, fold_seg(F, Acc, Seg, size(Seg)), Segs, I-1);
fold_segs(F, Acc, Segs, I) -> Acc.

fold_seg(F, Acc, Seg, I) when I >= 1 ->
    fold_seg(F, fold_bucket(F, Acc, element(I, Seg)), Seg, I-1);
fold_seg(F, Acc, Seg, I) -> Acc.

fold_bucket(F, Acc, [?kv(Key,Val)|Bkt]) ->
    fold_bucket(F, F(Key, Val, Acc), Bkt);
fold_bucket(F, Acc, []) -> Acc.

map_dict(F, D) ->
    Segs0 = tuple_to_list(D#dict.segs),
    Segs1 = map_seg_list(F, Segs0),
    D#dict{segs=list_to_tuple(Segs1)}.

map_seg_list(F, [Seg|Segs]) ->
    Bkts0 = tuple_to_list(Seg),
    Bkts1 = map_bkt_list(F, Bkts0),
    [list_to_tuple(Bkts1)|map_seg_list(F, Segs)];
map_seg_list(F, []) -> [].

map_bkt_list(F, [Bkt0|Bkts]) ->
    [map_bucket(F, Bkt0)|map_bkt_list(F, Bkts)];
map_bkt_list(F, []) -> [].

map_bucket(F, [?kv(Key,Val)|Bkt]) ->
    [?kv(Key,F(Key, Val))|map_bucket(F, Bkt)];
map_bucket(F, []) -> [].

filter_dict(F, D) ->
    Segs0 = tuple_to_list(D#dict.segs),
    {Segs1,Fc} = filter_seg_list(F, Segs0, [], 0),
    maybe_contract(D#dict{segs=list_to_tuple(Segs1)}, Fc).

filter_seg_list(F, [Seg|Segs], Fss, Fc0) ->
    Bkts0 = tuple_to_list(Seg),
    {Bkts1,Fc1} = filter_bkt_list(F, Bkts0, [], Fc0),
    filter_seg_list(F, Segs, [list_to_tuple(Bkts1)|Fss], Fc1);
filter_seg_list(F, [], Fss, Fc) ->
    {lists:reverse(Fss, []),Fc}.

filter_bkt_list(F, [Bkt0|Bkts], Fbs, Fc0) ->
    {Bkt1,Fc1} = filter_bucket(F, Bkt0, [], Fc0),
    filter_bkt_list(F, Bkts, [Bkt1|Fbs], Fc1);
filter_bkt_list(F, [], Fbs, Fc) ->
    {lists:reverse(Fbs),Fc}.

filter_bucket(F, [?kv(Key,Val)=E|Bkt], Fb, Fc) ->
    case F(Key, Val) of
	true -> filter_bucket(F, Bkt, [E|Fb], Fc);
	false -> filter_bucket(F, Bkt, Fb, Fc+1)
    end;
filter_bucket(F, [], Fb, Fc) ->
    {lists:reverse(Fb),Fc}.

%% get_bucket_s(Segments, Slot) -> Bucket.
%% put_bucket_s(Segments, Slot, Bucket) -> NewSegments.

get_bucket_s(Segs, Slot) ->
    SegI = ((Slot-1) div ?seg_size) + 1,
    BktI = ((Slot-1) rem ?seg_size) + 1,
    element(BktI, element(SegI, Segs)).

put_bucket_s(Segs, Slot, Bkt) ->
    SegI = ((Slot-1) div ?seg_size) + 1,
    BktI = ((Slot-1) rem ?seg_size) + 1,
    Seg = setelement(BktI, element(SegI, Segs), Bkt),
    setelement(SegI, Segs, Seg).

maybe_expand(T0, Ic) when T0#dict.size + Ic > T0#dict.exp_size ->
    T = maybe_expand_segs(T0),			%Do we need more segments.
    N = T#dict.n + 1,				%Next slot to expand into
    Segs0 = T#dict.segs,
    Slot1 = N - T#dict.bso,
    B = get_bucket_s(Segs0, Slot1),
    Slot2 = N,
    [B1|B2] = rehash(B, Slot1, Slot2, T#dict.maxn),
    Segs1 = put_bucket_s(Segs0, Slot1, B1),
    Segs2 = put_bucket_s(Segs1, Slot2, B2),
    T#dict{size=T#dict.size + Ic,
	   n=N,
	   exp_size=N * ?expand_load,
	   con_size=N * ?contract_load,
	   segs=Segs2};
maybe_expand(T, Ic) -> T#dict{size=T#dict.size + Ic}.

maybe_expand_segs(T) when T#dict.n == T#dict.maxn ->
    T#dict{maxn=2 * T#dict.maxn,
	   bso=2 * T#dict.bso,
	   segs=expand_segs(T#dict.segs, T#dict.empty)};
maybe_expand_segs(T) -> T.

maybe_contract(T, Dc) when T#dict.size - Dc < T#dict.con_size,
			   T#dict.n > ?seg_size ->
    N = T#dict.n,
    Slot1 = N - T#dict.bso,
    Segs0 = T#dict.segs,
    B1 = get_bucket_s(Segs0, Slot1),
    Slot2 = N,
    B2 = get_bucket_s(Segs0, Slot2),
    Segs1 = put_bucket_s(Segs0, Slot1, B1 ++ B2),
    Segs2 = put_bucket_s(Segs1, Slot2, []),	%Clear the upper bucket
    N1 = N - 1,
    maybe_contract_segs(T#dict{size=T#dict.size - Dc,
			       n=N1,
			       exp_size=N1 * ?expand_load,
			       con_size=N1 * ?contract_load,
			       segs=Segs2});
maybe_contract(T, Dc) -> T#dict{size=T#dict.size - Dc}.

maybe_contract_segs(T) when T#dict.n == T#dict.bso ->
    T#dict{maxn=T#dict.maxn div 2,
	   bso=T#dict.bso div 2,
	   segs=contract_segs(T#dict.segs)};
maybe_contract_segs(T) -> T.

%% rehash(Bucket, Slot1, Slot2, MaxN) -> [Bucket1|Bucket2].
%%  Yes, we should return a tuple, but this is more fun.

rehash([?kv(Key,Bag)=KeyBag|T], Slot1, Slot2, MaxN) ->
    [L1|L2] = rehash(T, Slot1, Slot2, MaxN),
    case erlang:hash(Key, MaxN) of
	Slot1 -> [[KeyBag|L1]|L2];
	Slot2 -> [L1|[KeyBag|L2]]
    end;
rehash([], Slot1, Slot2, MaxN) -> [[]|[]].

%% mk_seg(Size) -> Segment.

mk_seg(4) -> {[],[],[],[]};
mk_seg(8) -> {[],[],[],[],[],[],[],[]};
mk_seg(16) -> {[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]};
mk_seg(32) ->
    {[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],
     [],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]};
mk_seg(Size) -> list_to_tuple(lists:duplicate(Size, [])).

%% expand_segs(Segs, EmptySeg) -> NewSegs.
%% contract_segs(Segs) -> NewSegs.
%%  Expand/contract the segment tuple by doubling/halving the number
%%  of segments.  We special case the powers of 2 upto 32, this should
%%  catch most case.  N.B. the last element in the segments tuple is
%%  an extra element containing a default empty segment.

expand_segs({B1}, Empty) ->
    {B1,Empty};
expand_segs({B1,B2}, Empty) ->
    {B1,B2,Empty,Empty};
expand_segs({B1,B2,B3,B4}, Empty) ->
    {B1,B2,B3,B4,Empty,Empty,Empty,Empty};
expand_segs({B1,B2,B3,B4,B5,B6,B7,B8}, Empty) ->
    {B1,B2,B3,B4,B5,B6,B7,B8,
     Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty};
expand_segs({B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16}, Empty) ->
    {B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,
     Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,
     Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty};
expand_segs(Segs, Empty) ->
    list_to_tuple(tuple_to_list(Segs) ++ lists:duplicate(size(Segs), Empty)).

contract_segs({B1,_}) ->
    {B1};
contract_segs({B1,B2,_,_}) ->
    {B1,B2};
contract_segs({B1,B2,B3,B4,_,_,_,_}) ->
    {B1,B2,B3,B4};
contract_segs({B1,B2,B3,B4,B5,B6,B7,B8,_,_,_,_,_,_,_,_}) ->
    {B1,B2,B3,B4,B5,B6,B7,B8};
contract_segs({B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,
	       _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_}) ->
    {B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16};
contract_segs(Segs) ->
    Ss = size(Segs) div 2,
    list_to_tuple(lists:sublist(tuple_to_list(Segs), 1, Ss)).