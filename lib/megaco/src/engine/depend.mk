#-*-makefile-*-   ; force emacs to enter makefile-mode

$(EBIN)/megaco.$(EMULATOR): megaco.erl \
	../../include/megaco.hrl \
	megaco_internal.hrl \
	megaco_message_internal.hrl 

$(EBIN)/megaco_config.$(EMULATOR): megaco_config.erl \
	../../include/megaco.hrl \
	megaco_internal.hrl

$(EBIN)/megaco_digit_map.$(EMULATOR): megaco_digit_map.erl \
	megaco_message_internal.hrl \
	../text/megaco_text_tokens.hrl

$(EBIN)/megaco_encoder.$(EMULATOR): megaco_encoder.erl \
	../../include/megaco.hrl \
	megaco_internal.hrl

$(EBIN)/megaco_erl_dist_encoder.$(EMULATOR): megaco_erl_dist_encoder.erl \
	megaco_message_internal.hrl 

$(EBIN)/megaco_filter.$(EMULATOR): megaco_filter.erl \
	../../include/megaco.hrl \
	../../include/megaco_message_v1.hrl \
	megaco_internal.hrl 

$(EBIN)/megaco_messenger.$(EMULATOR): megaco_messenger.erl \
	../../include/megaco.hrl \
	megaco_internal.hrl \
	megaco_message_internal.hrl 

$(EBIN)/megaco_messenger_misc.$(EMULATOR): megaco_messenger_misc.erl \
	../../include/megaco.hrl \
	megaco_internal.hrl \
	megaco_message_internal.hrl 

$(EBIN)/megaco_misc_sup.$(EMULATOR): megaco_misc_sup.erl 

$(EBIN)/megaco_monitor.$(EMULATOR): megaco_monitor.erl 

$(EBIN)/megaco_sdp.$(EMULATOR): megaco_sdp.erl

$(EBIN)/megaco_stats.$(EMULATOR): megaco_stats.erl 

$(EBIN)/megaco_sup.$(EMULATOR): megaco_sup.erl

$(EBIN)/megaco_trans_sender.$(EMULATOR): megaco_trans_sender.erl 

$(EBIN)/megaco_trans_sup.$(EMULATOR): megaco_trans_sup.erl 

$(EBIN)/megaco_transport.$(EMULATOR): megaco_transport.erl 

$(EBIN)/megaco_user.$(EMULATOR): megaco_user.erl

$(EBIN)/megaco_user_default.$(EMULATOR): megaco_user_default.erl \
	../../include/megaco.hrl \
	../../include/megaco_message_v1.hrl
