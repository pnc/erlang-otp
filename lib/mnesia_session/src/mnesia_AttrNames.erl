%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: mnesia_AttrNames
%% Source: /ldisk/daily_build/otp_prebuild_r11b.2007-06-11_19/otp_src_R11B-5/lib/mnesia_session/src/mnesia_corba_session.idl
%% IC vsn: 4.2.13
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module(mnesia_AttrNames).
-ic_compiled("4_2_13").


-include("mnesia.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_sequence,{tk_string,0},0}.

%% returns id
id() -> "IDL:mnesia/AttrNames:1.0".

%% returns name
name() -> "mnesia_AttrNames".


