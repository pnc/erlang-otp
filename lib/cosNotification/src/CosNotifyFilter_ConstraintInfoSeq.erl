%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotifyFilter_ConstraintInfoSeq
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-06-10_20/otp_src_R12B-3/lib/cosNotification/src/CosNotifyFilter.idl
%% IC vsn: 4.2.18
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotifyFilter_ConstraintInfoSeq').
-ic_compiled("4_2_18").


-include("CosNotifyFilter.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_sequence,
            {tk_struct,"IDL:omg.org/CosNotifyFilter/ConstraintInfo:1.0",
                "ConstraintInfo",
                [{"constraint_expression",
                  {tk_struct,"IDL:omg.org/CosNotifyFilter/ConstraintExp:1.0",
                      "ConstraintExp",
                      [{"event_types",
                        {tk_sequence,
                            {tk_struct,
                                "IDL:omg.org/CosNotification/EventType:1.0",
                                "EventType",
                                [{"domain_name",{tk_string,0}},
                                 {"type_name",{tk_string,0}}]},
                            0}},
                       {"constraint_expr",{tk_string,0}}]}},
                 {"constraint_id",tk_long}]},
            0}.

%% returns id
id() -> "IDL:omg.org/CosNotifyFilter/ConstraintInfoSeq:1.0".

%% returns name
name() -> "CosNotifyFilter_ConstraintInfoSeq".



