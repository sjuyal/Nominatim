<?php
	require_once(dirname(dirname(__FILE__)).'/lib/init-website.php');
	require_once(CONST_BasePath.'/lib/log.php');

	$sOutputFormat = 'html';
	ini_set('memory_limit', '200M');

	$oDB =& getDB();
	if (!isset($_GET['days'])) $_GET['days'] = 1;
	$bReduced = false;
	if (isset($_GET['reduced'])) $bReduced = true;
	$sClass = false;
	if (isset($_GET['class'])) $sClass = $_GET['class'];

	$aPolygons = array();
	while(!sizeof($aPolygons))
	{
		$sSQL = 'select osm_type as "type",osm_id as "id",class as "key",type as "value",name->\'name\' as "name",';
		$sSQL .= 'country_code as "country",errormessage as "error message",updated';
		$sSQL .= " from import_polygon_error";
		if ($_GET['days'])
		{
			$sSQL .= " where updated > 'now'::timestamp - '".(int)$_GET['days']." day'::interval";
			$_GET['days']++;
		}
		if ($bReduced)
		{
			$sSQL .= " and errormessage like 'Area reduced%'";
		}
		if ($sClass)
		{
			$sSQL .= " and class = '".pg_escape_string($sClass)."'";
		}
		$sSQL .= " order by updated desc limit 1000";
		$aPolygons = $oDB->getAll($sSQL);
	}
//var_dump($aPolygons);
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8"/>
    <meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
    
    <title>Nominatim Broken Polygon Data</title>
    
    <meta name="description" content="List of broken OSM polygon data by date" lang="en-US" />

</head>

<body>
<style type="text/css">
table {
	border-width: 1px;
	border-spacing: 0px;
	border-style: solid;
	border-color: gray;
	border-collapse: collapse;
	background-color: white;
	margin: 10px;
}
table th {
	border-width: 1px;
	padding: 2px;
	border-style: inset;
	border-color: gray;
	border-left-color: #ddd;
	border-right-color: #ddd;
	background-color: #eee;
	-moz-border-radius: 0px 0px 0px 0px;
}
table td {
	border-width: 1px;
	padding: 2px;
	border-style: inset;
	border-color: gray;
	border-left-color: #ddd;
	border-right-color: #ddd;
	background-color: white;
	-moz-border-radius: 0px 0px 0px 0px;
}
</style>

<?php

	echo "<table>";
	echo "<tr>";
//var_dump($aPolygons[0]);
	foreach($aPolygons[0] as $sCol => $sVal)
	{
		echo "<th>".$sCol."</th>";
	}
	echo "<th>&nbsp;</th>";
	echo "<th>&nbsp;</th>";
	echo "</tr>";
	$aSeen = array();
	foreach($aPolygons as $aRow)
	{
		if (isset($aSeen[$aRow['type'].$aRow['id']])) continue;
		$aSeen[$aRow['type'].$aRow['id']] = 1;
		echo "<tr>";
		foreach($aRow as $sCol => $sVal)
		{
			switch($sCol)
			{
			case 'error message':
				if (preg_match('/Self-intersection\\[([0-9.\\-]+) ([0-9.\\-]+)\\]/',$sVal,$aMatch))
				{
					$aRow['lat'] = $aMatch[2];
					$aRow['lon'] = $aMatch[1];
					echo "<td><a href=\"http://www.openstreetmap.org/?lat=".$aMatch[2]."&lon=".$aMatch[1]."&zoom=18&layers=M&".$sOSMType."=".$aRow['id']."\">".($sVal?$sVal:'&nbsp;')."</a></td>";
				}
				else
				{
					echo "<td>".($sVal?$sVal:'&nbsp;')."</td>";
				}
				break;
			case 'id':
				$sOSMType = ($aRow['type'] == 'N'?'node':($aRow['type'] == 'W'?'way':($aRow['type'] == 'R'?'relation':'')));
				echo '<td><a href="http://www.openstreetmap.org/browse/'.$sOSMType.'/'.$aRow['id'].'" target="_new">'.$aRow['id'].'</a></td>';
				break;
			default:
				echo "<td>".($sVal?$sVal:'&nbsp;')."</td>";
				break;
			}
		}
		echo "<td><a href=\"http://localhost:8111/import?url=http://www.openstreetmap.org/api/0.6/".$sOSMType.'/'.$aRow['id']."/full\" target=\"josm\">josm</a></td>";
		if (isset($aRow['lat']))
		{
			echo "<td><a href=\"http://open.mapquestapi.com/dataedit/index_flash.html?lat=".$aRow['lat']."&lon=".$aRow['lon']."&zoom=18\" target=\"potlatch2\">P2</a></td>";
		}
		else
		{
			echo "<td>&nbsp;</td>";	
		}
		echo "</tr>";
	}
	echo "</table>";



//	include(CONST_BasePath.'/lib/template/details-'.$sOutputFormat.'.php');
?>
</body>
</html>
