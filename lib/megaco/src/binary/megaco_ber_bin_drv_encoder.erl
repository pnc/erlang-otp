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
%%----------------------------------------------------------------------
%% Purpose : Handle ASN.1 BER encoding of Megaco/H.248
%%----------------------------------------------------------------------

-module(megaco_ber_bin_drv_encoder).

-behaviour(megaco_encoder).

-export([encode_message/3, decode_message/3,
	
	 encode_transaction/3,
	 encode_action_requests/3,
	 encode_action_request/3,

	 version_of/2]).

%% Backward compatible functions:
-export([encode_message/2, decode_message/2]).

-include_lib("megaco/src/engine/megaco_message_internal.hrl").

-define(V1_ASN1_MOD, megaco_ber_bin_drv_media_gateway_control_v1).
-define(V2_ASN1_MOD, megaco_ber_bin_drv_media_gateway_control_v2).

-define(V1_TRANS_MOD, megaco_binary_transformer_v1).
-define(V2_TRANS_MOD, megaco_binary_transformer_v2).


%%----------------------------------------------------------------------
%% Convert a 'MegacoMessage' record into a binary
%% Return {ok, Binary} | {error, Reason}
%%----------------------------------------------------------------------


encode_message(EncodingConfig,  
	       #'MegacoMessage'{mess = #'Message'{version = V}} = MegaMsg) ->
    encode_message(EncodingConfig, V, MegaMsg).

encode_message(EncodingConfig, 1, MegaMsg) ->
    megaco_binary_encoder:encode_message(EncodingConfig, MegaMsg, 
					 ?V1_ASN1_MOD, ?V1_TRANS_MOD,
					 io_list);
encode_message(EncodingConfig, 2, MegaMsg) ->
    megaco_binary_encoder:encode_message(EncodingConfig, MegaMsg, 
					 ?V2_ASN1_MOD, ?V2_TRANS_MOD,
					 io_list).


%%----------------------------------------------------------------------
%% Convert a transaction (or transactions in the case of ack) record(s) 
%% into a binary
%% Return {ok, Binary} | {error, Reason}
%%----------------------------------------------------------------------

encode_transaction(EC, 1, Trans) ->
    %%     megaco_binary_encoder:encode_transaction(EC, Trans,
    %% 					     ?V1_ASN1_MOD, 
    %% 					     ?V1_TRANS_MOD,
    %% 					     io_list);
    {error, not_implemented};
encode_transaction(EC, 2, Trans) ->
    %%     megaco_binary_encoder:encode_transaction(EC, Trans, 
    %% 					     ?V2_ASN1_MOD, 
    %% 					     ?V2_TRANS_MOD,
    %% 					     io_list).
    {error, not_implemented}.


%%----------------------------------------------------------------------
%% Convert a list of ActionRequest record's into a binary
%% Return {ok, DeepIoList} | {error, Reason}
%%----------------------------------------------------------------------
encode_action_requests(EC, 1, ActReqs) when list(ActReqs) ->
%     megaco_binary_encoder:encode_action_requests(EC, ActReqs,
% 						 ?V1_ASN1_MOD, 
% 						 ?V1_TRANS_MOD,
% 						 io_list);
    {error, not_implemented};
encode_action_requests(EC, 2, ActReqs) when list(ActReqs) ->
%     megaco_binary_encoder:encode_action_requests(EC, ActReqs,
% 						 ?V1_ASN1_MOD, 
% 						 ?V1_TRANS_MOD,
% 						 io_list).
    {error, not_implemented}.


%%----------------------------------------------------------------------
%% Convert a ActionRequest record into a binary
%% Return {ok, DeepIoList} | {error, Reason}
%%----------------------------------------------------------------------
encode_action_request(EC, 1, ActReq) ->
%     megaco_binary_encoder:encode_action_request(EC, ActReq,
% 						?V1_ASN1_MOD, 
% 						?V1_TRANS_MOD,
% 						io_list);
    {error, not_implemented};
encode_action_request(EC, 2, ActReq) ->
%     megaco_binary_encoder:encode_action_request(EC, ActReq,
% 						?V1_ASN1_MOD, 
% 						?V1_TRANS_MOD,
% 						io_list).
    {error, not_implemented}.


%%----------------------------------------------------------------------
%% Convert a binary into a 'MegacoMessage' record
%% Return {ok, MegacoMessageRecord} | {error, Reason}
%%----------------------------------------------------------------------

version_of(EncodingConfig, Binary) ->
    AsnModV1 = ?V1_ASN1_MOD, 
    AsnModV2 = ?V2_ASN1_MOD, 
    megaco_binary_encoder:version_of(EncodingConfig, Binary, dynamic, 
				     AsnModV1, AsnModV2).
    
%% Old decode function
decode_message(EncodingConfig, Binary) ->
    decode_message(EncodingConfig, 1, Binary).

%% Select from message
%% This does not work at the moment so, we use version 1 for this
decode_message(EncodingConfig, dynamic, Binary) ->
    AsnModV1 = ?V1_ASN1_MOD, 
    AsnModV2 = ?V2_ASN1_MOD, 
    megaco_binary_encoder:decode_message_dynamic(EncodingConfig, Binary, 
 						 AsnModV1, AsnModV2, binary);

decode_message(EncodingConfig, 1, Binary) ->
    AsnMod   = ?V1_ASN1_MOD, 
    TransMod = ?V1_TRANS_MOD, 
    megaco_binary_encoder:decode_message(EncodingConfig, Binary, 
					 AsnMod, TransMod, binary);

decode_message(EncodingConfig, 2, Binary) ->
    AsnMod   = ?V2_ASN1_MOD, 
    TransMod = ?V2_TRANS_MOD, 
    megaco_binary_encoder:decode_message(EncodingConfig, Binary, 
					 AsnMod, TransMod, binary).