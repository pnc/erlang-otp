%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosEventDomainAdmin_CycleCreationForbidden
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-06-10_20/otp_src_R12B-3/lib/cosEventDomain/src/CosEventDomainAdmin.idl
%% IC vsn: 4.2.18
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosEventDomainAdmin_CycleCreationForbidden').
-ic_compiled("4_2_18").


-include("CosEventDomainAdmin.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,"IDL:omg.org/CosEventDomainAdmin/CycleCreationForbidden:1.0",
                   "CycleCreationForbidden",
                   [{"cyc",{tk_sequence,tk_long,0}}]}.

%% returns id
id() -> "IDL:omg.org/CosEventDomainAdmin/CycleCreationForbidden:1.0".

%% returns name
name() -> "CosEventDomainAdmin_CycleCreationForbidden".



