%%% This file was automatically generated by snmpc_mib_to_hrl version 4.11
%%% Date: 10-Jun-2008::20:26:47
-ifndef('SNMP-USER-BASED-SM-MIB').
-define('SNMP-USER-BASED-SM-MIB', true).

%% Oids

-define(usmNoAuthProtocol, [1,3,6,1,6,3,10,1,1,1]).

-define(usmHMACMD5AuthProtocol, [1,3,6,1,6,3,10,1,1,2]).

-define(usmHMACSHAAuthProtocol, [1,3,6,1,6,3,10,1,1,3]).

-define(usmNoPrivProtocol, [1,3,6,1,6,3,10,1,2,1]).

-define(usmDESPrivProtocol, [1,3,6,1,6,3,10,1,2,2]).

-define(snmpUsmMIB, [1,3,6,1,6,3,15]).

-define(usmMIBObjects, [1,3,6,1,6,3,15,1]).

-define(usmStats, [1,3,6,1,6,3,15,1,1]).
-define(usmStatsUnsupportedSecLevels, [1,3,6,1,6,3,15,1,1,1]).
-define(usmStatsUnsupportedSecLevels_instance, [1,3,6,1,6,3,15,1,1,1,0]).
-define(usmStatsNotInTimeWindows, [1,3,6,1,6,3,15,1,1,2]).
-define(usmStatsNotInTimeWindows_instance, [1,3,6,1,6,3,15,1,1,2,0]).
-define(usmStatsUnknownUserNames, [1,3,6,1,6,3,15,1,1,3]).
-define(usmStatsUnknownUserNames_instance, [1,3,6,1,6,3,15,1,1,3,0]).
-define(usmStatsUnknownEngineIDs, [1,3,6,1,6,3,15,1,1,4]).
-define(usmStatsUnknownEngineIDs_instance, [1,3,6,1,6,3,15,1,1,4,0]).
-define(usmStatsWrongDigests, [1,3,6,1,6,3,15,1,1,5]).
-define(usmStatsWrongDigests_instance, [1,3,6,1,6,3,15,1,1,5,0]).
-define(usmStatsDecryptionErrors, [1,3,6,1,6,3,15,1,1,6]).
-define(usmStatsDecryptionErrors_instance, [1,3,6,1,6,3,15,1,1,6,0]).

-define(usmUser, [1,3,6,1,6,3,15,1,2]).
-define(usmUserSpinLock, [1,3,6,1,6,3,15,1,2,1]).
-define(usmUserSpinLock_instance, [1,3,6,1,6,3,15,1,2,1,0]).

-define(usmUserTable, [1,3,6,1,6,3,15,1,2,2]).

-define(usmUserEntry, [1,3,6,1,6,3,15,1,2,2,1]).
-define(usmUserEngineID, 1).
-define(usmUserName, 2).
-define(usmUserSecurityName, 3).
-define(usmUserCloneFrom, 4).
-define(usmUserAuthProtocol, 5).
-define(usmUserAuthKeyChange, 6).
-define(usmUserOwnAuthKeyChange, 7).
-define(usmUserPrivProtocol, 8).
-define(usmUserPrivKeyChange, 9).
-define(usmUserOwnPrivKeyChange, 10).
-define(usmUserPublic, 11).
-define(usmUserStorageType, 12).
-define(usmUserStatus, 13).

-define(usmMIBConformance, [1,3,6,1,6,3,15,2]).

-define(usmMIBCompliances, [1,3,6,1,6,3,15,2,1]).

-define(usmMIBGroups, [1,3,6,1,6,3,15,2,2]).


%% Range values
-define(low_usmStatsUnsupportedSecLevels, 0).
-define(high_usmStatsUnsupportedSecLevels, 4294967295).
-define(low_usmStatsNotInTimeWindows, 0).
-define(high_usmStatsNotInTimeWindows, 4294967295).
-define(low_usmStatsUnknownUserNames, 0).
-define(high_usmStatsUnknownUserNames, 4294967295).
-define(low_usmStatsUnknownEngineIDs, 0).
-define(high_usmStatsUnknownEngineIDs, 4294967295).
-define(low_usmStatsWrongDigests, 0).
-define(high_usmStatsWrongDigests, 4294967295).
-define(low_usmStatsDecryptionErrors, 0).
-define(high_usmStatsDecryptionErrors, 4294967295).
-define(low_usmUserSpinLock, 0).
-define(high_usmUserSpinLock, 2147483647).
-define(low_usmUserEngineID, 5).
-define(high_usmUserEngineID, 32).
-define(low_usmUserName, 1).
-define(high_usmUserName, 32).
-define(low_usmUserSecurityName, 0).
-define(high_usmUserSecurityName, 255).
-define(low_usmUserPublic, 0).
-define(high_usmUserPublic, 32).


%% Enum definitions from usmUserStorageType
-define(usmUserStorageType_readOnly, 5).
-define(usmUserStorageType_permanent, 4).
-define(usmUserStorageType_nonVolatile, 3).
-define(usmUserStorageType_volatile, 2).
-define(usmUserStorageType_other, 1).

%% Enum definitions from usmUserStatus
-define(usmUserStatus_destroy, 6).
-define(usmUserStatus_createAndWait, 5).
-define(usmUserStatus_createAndGo, 4).
-define(usmUserStatus_notReady, 3).
-define(usmUserStatus_notInService, 2).
-define(usmUserStatus_active, 1).

%% Default values
-define(default_usmStatsUnsupportedSecLevels, 0).
-define(default_usmStatsNotInTimeWindows, 0).
-define(default_usmStatsUnknownUserNames, 0).
-define(default_usmStatsUnknownEngineIDs, 0).
-define(default_usmStatsWrongDigests, 0).
-define(default_usmStatsDecryptionErrors, 0).
-define(default_usmUserSpinLock, 0).
-define(default_usmUserAuthProtocol, [1,3,6,1,6,3,10,1,1,1]).
-define(default_usmUserAuthKeyChange, []).
-define(default_usmUserOwnAuthKeyChange, []).
-define(default_usmUserPrivProtocol, [1,3,6,1,6,3,10,1,2,1]).
-define(default_usmUserPrivKeyChange, []).
-define(default_usmUserOwnPrivKeyChange, []).
-define(default_usmUserPublic, []).
-define(default_usmUserStorageType, 3).

-endif.
