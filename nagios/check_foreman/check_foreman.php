<?php
#
# check_foreman.pl PNP4Nagios template
# v1.0 2013-11-01 $Id$
#

$opt[1] = "--title \"Statistics for $servicedesc on $hostname\" -l 0 ";

$def[1]  = "DEF:total=$RRDFILE[1]:$DS[1]:AVERAGE ";
$def[1] .= "AREA:total#E0FFE0:\"$NAME[1]\t\t\": ";
$def[1] .= "GPRINT:total:LAST:\"%2.2lf ".$UNIT[1]." curr\" ";
$def[1] .= "GPRINT:total:MAX:\"%2.2lf ".$UNIT[1]." max\" ";
$def[1] .= "GPRINT:total:MIN:\"%2.2lf ".$UNIT[1]." min\\n\" ";

$def[1] .= "DEF:failing=$RRDFILE[4]:$DS[4]:AVERAGE ";
$def[1] .= "AREA:failing#ff9999:\"$NAME[4]\t\" ";
$def[1] .= "GPRINT:failing:LAST:\"%2.2lf ".$UNIT[4]." curr\" ";
$def[1] .= "GPRINT:failing:MAX:\"%2.2lf ".$UNIT[4]." max\" ";
$def[1] .= "GPRINT:failing:MIN:\"%2.2lf ".$UNIT[4]." min\\n\" ";

$def[1] .= "DEF:out_of_sync=$RRDFILE[3]:$DS[3]:AVERAGE ";
$def[1] .= "AREA:out_of_sync#aaaaaa:\"$NAME[3]\t\":STACK ";
$def[1] .= "GPRINT:out_of_sync:LAST:\"%2.2lf ".$UNIT[3]." curr\" ";
$def[1] .= "GPRINT:out_of_sync:MAX:\"%2.2lf ".$UNIT[3]." max\" ";
$def[1] .= "GPRINT:out_of_sync:MIN:\"%2.2lf ".$UNIT[3]." min\\n\" ";

$def[1] .= "DEF:changed=$RRDFILE[2]:$DS[2]:AVERAGE ";
$def[1] .= "AREA:changed#99ccff:\"$NAME[2]\t\":STACK ";
$def[1] .= "GPRINT:changed:LAST:\"%2.2lf ".$UNIT[2]." curr\" ";
$def[1] .= "GPRINT:changed:MAX:\"%2.2lf ".$UNIT[2]." max\" ";
$def[1] .= "GPRINT:changed:MIN:\"%2.2lf ".$UNIT[2]." min\\n\" ";

# Same again, with a line for emphasis
# These lines go last, so they don't get drawn over by the area graphs
$def[1] .= "LINE:total#40C040: ";
$def[1] .= "LINE:failing#C04040: ";
$def[1] .= "LINE:out_of_sync#404040::STACK ";
$def[1] .= "LINE:changed#4040C0::STACK ";

if($WARN[4] != ""){
  	$def[1] .= rrd::hrule($WARN[4], "#FFFF00", "Warning  ".$WARN[4].$UNIT[4]."\\n");
}
if($CRIT[4] != ""){
  	$def[1] .= rrd::hrule($CRIT[4], "#FF0000", "Critical ".$CRIT[4].$UNIT[4]."\\n");
}

#error_log($def[1]);
#error_log("WARN: ". implode(", ",array_values($WARN)). "   WARN 2 = $WARN[2]   UNIT 2  = $UNIT[2]");
#error_log("CRIT: ". implode(", ",array_values($CRIT)) . "   CRIT 2 = $CRIT[2]   UNIT 2  = $UNIT[2]");
?>
