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
-module(inet_udp).

-export([open/1, open/2, close/1]).
-export([send/2, send/4, recv/2, recv/3, connect/3]).
-export([controlling_process/2]).
-export([fdopen/2]).

-export([getserv/1, getaddr/1, getaddr/2]).

-include("inet_int.hrl").

%% inet_udp port lookup
getserv(Port) when integer(Port) -> {ok, Port};
getserv(Name) when atom(Name)    -> inet:getservbyname(Name,udp).

%% inet_udp address lookup
getaddr(Address) -> inet:getaddr(Address, inet).
getaddr(Address,Timer) -> inet:getaddr_tm(Address, inet, Timer).

open(Port) -> open(Port, []).

open(Port, Opts) when Port >= 0, Port =< 16#ffff ->
    case inet:udp_options([{port,Port} | Opts], inet) of
	{error, Reason} -> exit(Reason);
	{ok, R} ->
	    Fd       = R#udp_opts.fd,
	    BAddr    = R#udp_opts.ifaddr,
	    BPort    = R#udp_opts.port,
	    SockOpts = R#udp_opts.opts,
	    inet:open(Fd,BAddr,BPort,SockOpts,dgram,inet,?MODULE)
    end.

send(S,{A,B,C,D},P,Data) when ?ip(A,B,C,D), P>=0,P=<16#ffff ->
    prim_inet:sendto(S, {A,B,C,D}, P, Data).

send(S, Data) ->
    prim_inet:sendto(S, {0,0,0,0}, 0, Data).
    
connect(S, {A,B,C,D}, P) when ?ip(A,B,C,D), P>=0, P=<16#ffff->
    prim_inet:connect(S, {A,B,C,D}, P).

recv(S,Len) ->
    prim_inet:recvfrom(S, Len).

recv(S,Len,Time) ->
    prim_inet:recvfrom(S, Len, Time).

close(S) ->
    inet:udp_close(S).

%%
%% Set controlling process:
%% 1) First sync socket into a known state
%% 2) Move all messages onto the new owners message queue
%% 3) Commit the owner 
%% 4) Wait for ack of new Owner (since socket does some link and unlink)
%%

controlling_process(Socket, NewOwner) ->
    inet:udp_controlling_process(Socket, NewOwner).

%%
%% Create a port/socket from a file descriptor 
%%
fdopen(Fd, Opts) ->
    inet:fdopen(Fd, Opts, dgram, inet, ?MODULE).