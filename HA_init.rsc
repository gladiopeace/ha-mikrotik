:do {
/system script
remove [find name=ha_checkchanges_new]
add name=ha_checkchanges_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":if ([:len [/system script job find where script=\"ha_checkchanges\"]] > 1) do={:error \"already running checkchanges\"; } \
	\n:global isMaster\
	\n:global isStandbyInSync\
	\n:global haPassword\
	\n:global haAddressOther\
	\n:global haCheckLastCheckTS  \"\$[/system clock get date] \$[/system clock get time] \$[/system clock get time-zone-name]\"\
	\n:global haCheckStandbyVer\
	\n:global haCheckMasterVer\
	\n:do {\
	\n   :if (\$isMaster) do {\
	\n      /file print file=HA_get-version.txt; /file set [find name=\"HA_get-version.txt\"] contents=\":global haConfigVer\\n[:put \\\"XXX \\\$haConfigVer YYYY\\\"]\\n\"\
	\n         /tool fetch upload=yes src-path=HA_get-version.txt dst-path=HA_get-version.auto.rsc address=\$haAddressOther user=ha password=\$haPassword mode=ftp \
	\n         /file remove [find name=\"HA_standby-haConfigVer.txt\"]\
	\n         /tool fetch upload=no src-path=HA_get-version.auto.log dst-path=HA_standby-haConfigVer.txt address=\$haAddressOther user=ha password=\$haPassword mode=ftp \
	\n         :local haCheckStandbyVerTmp [/file get [find name=\"HA_standby-haConfigVer.txt\"] contents]\
	\n         :global haCheckStandbyVer [:pick \$haCheckStandbyVerTmp ([:find \$haCheckStandbyVerTmp \"XXX \"]+4) [:find \$haCheckStandbyVerTmp \" YYYY\"]]\
	\n         :global haMasterConfigVer\
	\n         [/system script run [find name=\"ha_setconfigver\"]]\
	\n         :global haCheckMasterVer \$haMasterConfigVer\
	\n         /file remove [find name=\"HA_standby-haConfigVer.txt\"]\
	\n         :put \"MASTER VERSION: ! \$haCheckMasterVer !\"\
	\n         :put \"STANDB VERSION: ! \$haCheckStandbyVer !\"\
	\n         :if (\$haCheckStandbyVer != \$haCheckMasterVer) do {\
	\n            :put \"NEED TO PUSH\"\
	\n            :global isStandbyInSync false\
	\n            /system script run [find name=\"ha_pushbackup\"]\
	\n         } else {\
	\n            :global isStandbyInSync true\
	\n            :put \"GOOD\"\
	\n         }\
	\n   }\
	\n} on-error={\
	\n   :put \"GOT ERROR\"\
	\n   :global isStandbyInSync false\
	\n}\
	\n"
remove [find name=ha_config_new]
add name=ha_config_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source="/system script run [find name=\"ha_config_base\"]\
	\n:global haNetwork \"169.254.23.0\"\
	\n:global haNetmask \"255.255.255.0\"\
	\n:global haNetmaskBits \"24\"\
	\n:global haAddressA \"169.254.23.1\"\
	\n:global haAddressB \"169.254.23.2\"\
	\n:global haAddressVRRP \"169.254.23.10\"\
	\n"
remove [find name=ha_functions_new]
add name=ha_functions_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":global HADebug do={\
	\n   :put \$1\
	\n   /log warning \$1\
	\n}\
	\n\
	\n:global HAPushStandby do={\
	\n   /system script run [find name=\"ha_pushbackup\"]\
	\n}\
	\n\
	\n:global HASyncStandby do={\
	\n   /system script run [find name=\"ha_checkchanges\"]\
	\n}\
	\n\
	\n:global HAInstall do={\
	\n   #\$HAInstall interface=\"ether8\" macA=\"E1:81:8C:35:13:8C\" macB=\"E1:81:8C:35:10:08\" password=\"a25d89ba41236c40726ff9e7ffee1d202992f61c\"\
	\n   :if ([:typeof \$interface] = \"nothing\") do {:error \"interface missing\"};\
	\n   :if ([:typeof \$macA] = \"nothing\") do {:error \"macA missing\"};\
	\n   :if ([:typeof \$macB] = \"nothing\") do {:error \"macB missing\"};\
	\n   :if ([:typeof \$password] = \"nothing\") do {:error \"password missing\"};\
	\n   /system script remove [find name=ha_config_base]\
	\n   /system script add name=ha_config_base owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=\":global haPassword \\\"\$password\\\"\\\
	\n   \\n:global haInterface \\\"\$interface\\\"\\\
	\n   \\n:global haMacA \\\"\$macA\\\"\\\
	\n   \\n:global haMacB \\\"\$macB\\\"\"\
	\n   /system script run [find name=\"ha_install\"]\
	\n}\
	\n"
remove [find name=ha_install_new]
add name=ha_install_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source="/system script run [find name=\"ha_config\"]\
	\n:global haPassword\
	\n:global haInterface\
	\n:global haMacA\
	\n:global haMacB\
	\n:global haNetmaskBits\
	\n:global haAddressOther\
	\n:global isMaster\
	\n:global haMacOther\
	\n\
	\n:if ([:len [/interface find where default-name=\"\$haInterface\" name=\"\$haInterface\"]] != 1) do {\
	\n   :error \"Unable to find interface named \$haInterface with default-name that matches name. Make sure you don't rename these interfaces, leave default-name as-is.\"\
	\n}\
	\n\
	\n:local mac [[/interface ethernet get [find default-name=\"\$haInterface\"] orig-mac-address]]\
	\n:if (\$mac != \$haMacA and \$mac != \$haMacB) do {\
	\n   :error \"Interface \$haInterface MAC \$mac does not match (A=\$haMacA or B=\$haMacB) - please check config\\r\\nUse orig-mac address!\"\
	\n}\
	\n\
	\n:local pingMac \$haMacA\
	\n:if (\$mac = \$haMacA) do {\
	\n   :set pingMac \$haMacB\
	\n}\
	\n\
	\n:put \$mac\
	\n:put \$pingMac\
	\n\
	\n:if ([/ping \$pingMac count=1] = 0) do {\
	\n   :error \"Are you sure the other device is configured properly? I am unable to ping MAC \$pingMac\"\
	\n}\
	\n\
	\n:if ([:len [/ip address find where interface=\"\$haInterface\" and comment!=\"HA_AUTO\"]] > 0) do {\
	\n   :error \"Interface \$haInterface has IP addresses. HA should completely own the interface and it cannot be used by anything else. Please correct\"\
	\n}\
	\n\
	\n:if ([:len [/file find name=HA_backup_beforeHA.backup]] = 0) do {\
	\n   system backup save name=HA_backup_beforeHA dont-encrypt=yes\
	\n   /export file=HA_backup_beforeHA.rsc\
	\n}\
	\n\
	\n:if (!\$isMaster) do {\
	\n   :put \"I am not master - running ha_startup first\"\
	\n   /system script run \"ha_startup\"\
	\n} else {\
	\n   :put \"I am already master! Skipping my own bootstrap...\"\
	\n}\
	\n\
	\n:put \"###\"\
	\n:put \"#Maybe try: /tool mac-telnet \$haMacOther\"\
	\n:put \"###PASTE THIS ON THE OTHER DEVICE - YOUR CONFIG WILL BE RESET AND LOST!!!###\"\
	\n:put \":global mac [[/interface ethernet get [find default-name=\\\"\$haInterface\\\"] orig-mac-address]]\"\
	\n:put \":if (\\\$mac = \\\"\$haMacA\\\" and \\\$mac = \\\"\$haMacB\\\") do {\"\
	\n:put \"   :error \\\"Interface \$haInterface MAC \\\$mac does not match (A=\$haMacA or B=\$haMacB) - please check config\\\\r\\\\nUse orig-mac address!\\\"\"\
	\n:put \"}\"\
	\n#Try to backup the local device before HA, just in case.\
	\n:put \":if ([:len [/file find name=HA_backup_beforeHA.backup]] = 0) do {\"\
	\n:put \"   /system backup save name=HA_backup_beforeHA dont-encrypt=yes\"\
	\n:put \"   /export file=HA_backup_beforeHA.rsc\"\
	\n:put \"}\"\
	\n#Oh this is ridicullous, we can't create a file that doesn't end in .txt any other way. Use export to create a rsc file extension.\
	\n:put \"/export file=HA_bootstrap.rsc\"\
	\n#Seems to be a race condition between the export and the visibility, delay a bit.\
	\n:put \"/delay 2\"\
	\n:put \"/file print file=HA_bootstrap.rsc\"\
	\n:put \"/file set [find name=HA_bootstrap.rsc] contents=\\\"/ip address add address=\\\\\\\"\$haAddressOther/\$haNetmaskBits\\\\\\\" interface=\$haInterface; /user add name=ha group=full password=\\\\\\\"\$haPassword\\\\\\\";\\\"\"\
	\n:put \"/system reset-configuration no-defaults=yes keep-users=no skip-backup=yes run-after-reset=HA_bootstrap.rsc\"\
	\n:put \"###END OF PASTE FOR OTHER DEVICE###\"\
	\n:put \"###\"\
	\n"
remove [find name=ha_onbackup_new]
add name=ha_onbackup_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":global isMaster false\
	\n:global haNetmaskBits\
	\n:global haInterface\
	\n/interface ethernet disable [find default-name!=\"\$haInterface\"]\
	\n:execute \"ha_setidentity\"\
	\n:do { :local k [/system script find name=\"on_backup\"]; if ([:len \$k] = 1) do={ /system script run \$k } } on-error={ :put \"on_backup failed\" }\
	\n"
remove [find name=ha_onmaster_new]
add name=ha_onmaster_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":global isMaster true\
	\n:global haNetmaskBits\
	\n:global haInterface\
	\n/interface ethernet enable [find]\
	\n:execute \"ha_setidentity\"\
	\n:do { :local k [/system script find name=\"on_master\"]; if ([:len \$k] = 1) do={ /system script run \$k } } on-error={ :put \"on_master failed\" }\
	\n"
remove [find name=ha_pushbackup_new]
add name=ha_pushbackup_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":if ([:len [/system script job find where script=\"ha_pushbackup\"]] > 1) do={:error \"already running pushbackup\"; } \
	\n:global haPassword\
	\n:global isMaster\
	\n:global haAddressOther\
	\n:if (!\$isMaster) do {\
	\n   :error \"NOT MASTER\"\
	\n} else {\
	\n   #Really? this is the only way to create directories?\
	\n   :local mkdirCode \":do { /ip smb shares add comment=HA_AUTO name=mkdir disabled=yes directory=/skins } on-error={}\"\
	\n   :foreach k in [/file find name~\"^[^H][^A][^_]\" and type=\"directory\"] do={\
	\n      :local dir [/file get \$k name]\
	\n      :set mkdirCode \"\$mkdirCode\\r\\n/ip smb shares set [find comment=HA_AUTO] directory=\\\"\$dir\\\"\"\
	\n   }\
	\n   :set mkdirCode \"\$mkdirCode\\r\\n/ip smb shares remove [find comment=HA_AUTO]\\r\\n\"\
	\n   #eh - good chance to keep files in sync, just delete everything, we will reupload. is this going to reduce life of nvram?\
	\n   :set mkdirCode \"/file remove [find name~\\\"^[^H][^A][^_]\\\" and type!=\\\"directory\\\"]\\r\\n/delay 2;\\r\\n\$mkdirCode\"\
	\n   /file print file=HA_mkdirs.txt\
	\n   /file set [find name=\"HA_mkdirs.txt\"] contents=\$mkdirCode\
	\n   :put \"mkdirCode: \$mkdirCode end_mkDirCode\"\
	\n   /tool fetch upload=yes src-path=HA_mkdirs.txt dst-path=HA_mkdirs.auto.rsc address=\$haAddressOther user=ha password=\$haPassword mode=ftp \
	\n   \
	\n   :foreach k in [/file find name~\"^[^H][^A][^_]\" and type!=\"directory\"] do={\
	\n      :local xferfile [/file get \$k name]\
	\n      :put \"Transferring: \$xferfile\"\
	\n      :do {\
	\n         /tool fetch upload=yes src-path=\$xferfile dst-path=\$xferfile address=\$haAddressOther user=ha password=\$haPassword mode=ftp\
	\n      } on-error={\
	\n         :put \"Failed to transfer \$xferfile\"\
	\n      }\
	\n   }\
	\n\
	\n   :if ([:len [/file find name=HA_dsa]] <= 0) do={ \
	\n      /ip ssh export-host-key key-file-prefix=\"HA\"\
	\n   }\
	\n\
	\n   /tool fetch upload=yes src-path=HA_dsa dst-path=HA_dsa address=\$haAddressOther user=ha password=\$haPassword mode=ftp  \
	\n   /tool fetch upload=yes src-path=HA_rsa dst-path=HA_rsa address=\$haAddressOther user=ha password=\$haPassword mode=ftp  \
	\n\
	\n\
	\n   :global haMasterConfigVer\
	\n   [/system script run [find name=\"ha_setconfigver\"]]\
	\n   /file print file=HA_run-after-hastartup.txt\
	\n   /file set [find name=HA_run-after-hastartup.txt] contents=\":global haConfigVer \\\"\$haMasterConfigVer\\\"\"\
	\n   /tool fetch upload=yes src-path=HA_run-after-hastartup.txt dst-path=HA_run-after-hastartup.rsc address=\$haAddressOther user=ha password=\$haPassword mode=ftp \
	\n\
	\n   /export file=HA_b2s.rsc\
	\n   /system backup save name=HA_b2s.backup password=p\
	\n   /tool fetch upload=yes src-path=HA_b2s.rsc dst-path=HA_b2s.rsc address=\$haAddressOther user=ha password=\$haPassword mode=ftp  \
	\n   /tool fetch upload=yes src-path=HA_b2s.backup dst-path=HA_b2s.backup address=\$haAddressOther user=ha password=\$haPassword mode=ftp  \
	\n   /file print file=HA_restore-backup.rsc; /file set [find name=\"HA_restore-backup.rsc.txt\"] contents=\"/system backup load name=HA_b2s.backup password=p\"\
	\n   :do {\
	\n      /tool fetch upload=yes src-path=HA_restore-backup.rsc.txt dst-path=HA_restore-backup.auto.rsc address=\$haAddressOther user=ha password=\$haPassword mode=ftp \
	\n   } on-error={\
	\n      :put \"OK - status failed is OK from last fetch, standby is rebooting.\"\
	\n   }\
	\n}\
	\n"
remove [find name=ha_setconfigver_new]
add name=ha_setconfigver_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":local verHistory [:tostr [:pick [/system history print detail as-value] 1]]\
	\n:local verCertificate [:tostr [/certificate find]]\
	\n:local verFile [:tostr [/file find name~\"^[^H][^A][^_]\"]]\
	\n:local haVer \"history=\$verHistory file=\$verFile certificate=\$verCertificate\"\
	\n:global haMasterConfigVer \$haVer\
	\n"
remove [find name=ha_setidentity_new]
add name=ha_setidentity_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":global haIdentity\
	\n:global isMaster\
	\n:local sysIdentity [/system identity get name]\
	\n:local haPos [:find \$sysIdentity \"_HA_\" 0]\
	\nif (\$haPos > 0) do {\
	\n   :set sysIdentity [:pick \$sysIdentity 0 \$haPos]\
	\n}\
	\n:if (\$isMaster) do {\
	\n   /system identity set name=\"\$sysIdentity_HA_\$haIdentity_ACTIVE\"\
	\n} else {\
	\n   /system identity set name=\"\$sysIdentity_HA_\$haIdentity_STANDBY\"\
	\n}\
	\n"
remove [find name=ha_startup_new]
add name=ha_startup_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source="#:do {\
	\n:execute \"/interface print detail\" file=\"HA_boot_interface_print.txt\"\
	\n/log warning \"ha_startup: START\"\
	\n/system script run [find name=ha_functions]\
	\n/log warning \"ha_startup: 0.1\"\
	\n/system script run [find name=\"ha_config\"]\
	\n/log warning \"ha_startup: 0.2\"\
	\n:global haInterface\
	\n#Sometimes the hardware isn't initialized by the time we get here. Wait until we can see the interface.\
	\n#https://github.com/svlsResearch/ha-mikrotik/issues/1\
	\n:while ([:len [/interface find where name=\"\$haInterface\"]]!=1) do={\
	\n   /log error \"ha_startup: delaying for hardware...cant find \$haInterface\"\
	\n   :delay .1\
	\n}\
	\n/log warning \"ha_startup: 0.3\"\
	\n/interface ethernet disable [find]\
	\n:global haStartupHAVersion \"0.2alpha - 1d439fa83ee39f53eab4188362fdaf543439e4e4\"\
	\n:global isStandbyInSync false\
	\n:global isMaster false\
	\n:global haPassword\
	\n:global haMacA\
	\n:global haMacB\
	\n:global haAddressA\
	\n:global haAddressB\
	\n:global haAddressVRRP\
	\n:global haNetmask\
	\n:global haNetmaskBits\
	\n:global haNetwork\
	\n:global haMacOther\
	\n:global haMacMe\
	\n:global haAddressOther\
	\n:global haAddressMe\
	\n\
	\n/log warning \"ha_startup: 1 \$haInterface\"\
	\n/system scheduler remove [find comment=\"HA_AUTO\"]\
	\n\
	\n#Pause on-error just in case we error out before the spin loop - hope 5 seconds is enough.\
	\n/system scheduler add comment=HA_AUTO name=ha_startup on-event=\":do {:global haInterface; /system script run [find name=ha_startup]; } on-error={ :delay 5; /interface ethernet disable [find default-name!=\\\"\\\$haInterface\\\"]; /log error \\\"ha_startup: FAILED - DISABLED ALL INTERFACES\\\" }\" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive start-time=startup \
	\n\
	\n#/interface ethernet reset-mac-address\
	\n/ip address remove [find interface=\"\$haInterface\"]\
	\n/ip address remove [find comment=\"HA_AUTO\"]\
	\n/interface vrrp remove [find name=\"HA_VRRP\"]\
	\n/ip address remove [find interface=\"HA_VRRP\"]\
	\n/ip firewall filter remove [find comment=\"HA_AUTO\"]\
	\n/ip service set [find name=\"ftp\"] disabled=yes\
	\n\
	\n/interface ethernet enable [find default-name=\"\$haInterface\"] \
	\n/log warning \"ha_startup: 2\"\
	\n/interface ethernet get [find default-name=\"\$haInterface\"] orig-mac-address\
	\n/log warning \"ha_startup: 2.2\"\
	\n:local mac [[/interface ethernet get [find default-name=\"\$haInterface\"] orig-mac-address]]\
	\n/log warning \"ha_startup: 3\"\
	\n:if (\"\$mac\" = \"\$haMacA\") do {\
	\n   :global haIdentity \"A\"\
	\n   /log warning \"I AM A\"\
	\n   /ip address add interface=\$haInterface address=\$haAddressA netmask=\$haNetmask comment=\"HA_AUTO\"\
	\n   :global haAddressMe \$haAddressA\
	\n   :global haAddressOther \$haAddressB\
	\n   :global haMacMe \$haMacA\
	\n   :global haMacOther \$haMacB\
	\n} else {\
	\n   :if (\"\$mac\" = \"\$haMacB\") do {\
	\n      :global haIdentity \"B\"\
	\n      /log warning \"I AM B\"\
	\n      /ip address add interface=\$haInterface address=\$haAddressB netmask=\$haNetmask comment=\"HA_AUTO\"\
	\n      :global haAddressMe \$haAddressB\
	\n      :global haAddressOther \$haAddressA\
	\n      :global haMacMe \$haMacB\
	\n      :global haMacOther \$haMacA\
	\n   } else {\
	\n      #This is a very strange bug...maybe just in the CCR? Sometimes when the unit comes up, ethernet interfaces sometimes have swapped positions?\
	\n      #A reboot clears this error - it is very odd, I don't know if it is a race condition in hardware initialization or something.\
	\n      #I'm not sure this covers ALL cases, since it only checks the MAC of the one interface our HA runs over. It might not right now :(\
	\n      #Do we need to track all MACs to make sure they are in the right order? This seems like a general problem with the platform but I don't understand the extent of it.\
	\n      #Am I causing this?\
	\n      :global haIdentity \"UKNOWN\"\
	\n      /log warning \"I AM UNKNOWN - WRONG MAC\"\
	\n      /delay 15\
	\n      :execute \"/system reboot\"\
	\n      /delay 1000\
	\n   }\
	\n}\
	\n\
	\n/ip route remove [find comment=\"HA_AUTO\"]   \
	\n/ip route add gateway=\$haAddressOther distance=250 comment=HA_AUTO\
	\n\
	\n/log warning \"ha_startup: 4\"\
	\n\
	\n#If firewall is empty, place-before=0 won't work. Add first rule.\
	\n:if ([:len [/ip firewall filter find]] = 0) do {\
	\n   /log warning \"ha_startup: 4.1\"\
	\n   /ip firewall filter add chain=output action=accept out-interface=\$haInterface comment=\"HA_AUTO\"\
	\n   /ip firewall filter add chain=input action=accept in-interface=\$haInterface comment=\"HA_AUTO\"\
	\n} else {\
	\n   /log warning \"ha_startup: 4.2\"\
	\n   /ip firewall filter add chain=output action=accept out-interface=\$haInterface comment=\"HA_AUTO\" place-before=0\
	\n   /ip firewall filter add chain=input action=accept in-interface=\$haInterface comment=\"HA_AUTO\" place-before=0\
	\n}\
	\n/log warning \"ha_startup: 4.3\"\
	\n\
	\n/log warning \"ha_startup: 5\"\
	\n/interface vrrp add interface=\$haInterface version=3 interval=1 name=HA_VRRP on-backup=\"ha_onbackup\" on-master=\"ha_onmaster\" \
	\n/ip address add address=\$haAddressVRRP netmask=255.255.255.255 interface=HA_VRRP comment=\"HA_AUTO\"\
	\n\
	\n/log warning \"ha_startup: 6\"\
	\n/system scheduler add comment=HA_AUTO interval=30m name=ha_exportcurrent on-event=\"/export file=\\\"HA_current.rsc\\\"\" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive start-date=jan/20/2000 start-time=22:37:10\
	\n/system scheduler add interval=10m name=ha_checkchanges on-event=ha_checkchanges policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive start-date=jan/1/2000 start-time=18:00:30 comment=HA_AUTO\
	\n#Still need this - things like DHCP leases dont cause a system config change, we want to backup periodically.\
	\n/system scheduler add comment=HA_AUTO interval=24h name=ha_auto_pushbackup on-event=ha_pushbackup policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive start-date=jan/20/2000 start-time=05:00:00\
	\n/log warning \"ha_startup: 7\"\
	\n:if ([:len [/file find name=\"HA_dsa\"]] = 1) do={\
	\n   /ip ssh import-host-key private-key-file=HA_rsa\
	\n}\
	\n:if ([:len [/file find name=\"HA_rsa\"]] = 1) do={\
	\n   /ip ssh import-host-key private-key-file=HA_rsa\
	\n}\
	\n/user remove [find comment=HA_AUTO]\
	\n/user add address=\"\$haNetwork/\$haNetmaskBits\" comment=HA_AUTO group=full name=ha password=\"\$haPassword\"\
	\n/log warning \"ha_startup: 8\"\
	\n#So you dont get annoyed with constant beeping\
	\n/system routerboard settings set silent-boot=yes\
	\n\
	\n:foreach service in [:toarray \"ftp,telnet,ssh\"] do={\
	\n   :local serviceAddresses \"\"\
	\n   :foreach k in=[/ip service get [find name=\$service] address] do={\
	\n      :if (\$k != \"\$haAddressA/32\" and \$k != \"\$haAddressB/32\" and \$k != \"\$haAddressVRRP/32\") do {\
	\n         :set serviceAddresses \"\$serviceAddresses,\$k\"\
	\n      }\
	\n   }\
	\n   :set serviceAddresses \"\$serviceAddresses,\$haAddressA,\$haAddressB,\$haAddressVRRP\"\
	\n   /ip service set [find name=\$service] address=[:toarray \$serviceAddresses]\
	\n}\
	\n\
	\n:if ([:len [/file find where name=\"HA_run-after-hastartup.rsc\"]] > 0) do {\
	\n   /import HA_run-after-hastartup.rsc\
	\n}\
	\n/delay 5\
	\n#We need FTP to do our HA work\
	\n/ip service set [find name=\"ftp\"] disabled=no\
	\n\
	\n/log warning \"ha_startup: DONE\"\
	\n:put \"ha_startup: DONE\"\
	\n\
	\n#} on-error={\
	\n#   /log warning \"ha_startup: FAILED got error! disabling all interfaces!\"\
	\n#   /interface ethernet disable [find]\
	\n#}\
	\n\
	\n:do { :local k [/system script find name=\"on_startup\"]; if ([:len \$k] = 1) do={ /system script run \$k } } on-error={ :put \"on_startup failed\" }\
	\n"
remove [find name=ha_switchrole_new]
add name=ha_switchrole_new owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source=":global isMaster\
	\n:if (\$isMaster) do {\
	\n   :put \"I am master - switching role\"\
	\n   /system script run [find name=\"ha_pushbackup\"]\
	\n   :put \"delaying 60\"\
	\n   /delay 60\
	\n   :if (\$isMaster && [/ping 169.254.23.3 count=1 interface=ether1 ttl=1] >= 1) do {\
	\n      :put \"REBOOTING MYSELF\"\
	\n      :execute \"/system reboot\"\
	\n   } else {\
	\n      :put \"NOT REBOOTING MYSELF! SLAVE IS NOT UP OR I AM NOT MASTER!\"\
	\n   }\
	\n} else {\
	\n   :put \"I am NOT master - nothing to do\"\
	\n}\
	\n"
remove [find name=ha_checkchanges_old]
remove [find name=ha_checkchanges]
set name=ha_checkchanges [find name=ha_checkchanges_new]
remove [find name=ha_config_old]
remove [find name=ha_config]
set name=ha_config [find name=ha_config_new]
remove [find name=ha_functions_old]
remove [find name=ha_functions]
set name=ha_functions [find name=ha_functions_new]
remove [find name=ha_install_old]
remove [find name=ha_install]
set name=ha_install [find name=ha_install_new]
remove [find name=ha_onbackup_old]
remove [find name=ha_onbackup]
set name=ha_onbackup [find name=ha_onbackup_new]
remove [find name=ha_onmaster_old]
remove [find name=ha_onmaster]
set name=ha_onmaster [find name=ha_onmaster_new]
remove [find name=ha_pushbackup_old]
remove [find name=ha_pushbackup]
set name=ha_pushbackup [find name=ha_pushbackup_new]
remove [find name=ha_setconfigver_old]
remove [find name=ha_setconfigver]
set name=ha_setconfigver [find name=ha_setconfigver_new]
remove [find name=ha_setidentity_old]
remove [find name=ha_setidentity]
set name=ha_setidentity [find name=ha_setidentity_new]
remove [find name=ha_startup_old]
remove [find name=ha_startup]
set name=ha_startup [find name=ha_startup_new]
remove [find name=ha_switchrole_old]
remove [find name=ha_switchrole]
set name=ha_switchrole [find name=ha_switchrole_new]
/system script run [find name=ha_functions]
}
