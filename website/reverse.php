<?php
	@define('CONST_ConnectionBucket_PageType', 'Reverse');

	require_once(dirname(dirname(__FILE__)).'/lib/init-website.php');
	require_once(CONST_BasePath.'/lib/log.php');
	require_once(CONST_BasePath.'/lib/PlaceLookup.php');
	require_once(CONST_BasePath.'/lib/ReverseGeocode.php');

	if (strpos(CONST_BulkUserIPs, ','.$_SERVER["REMOTE_ADDR"].',') !== false)
	{
		$fLoadAvg = getLoadAverage();
		if ($fLoadAvg > 2) sleep(60);
		if ($fLoadAvg > 4) sleep(120);
		if ($fLoadAvg > 6)
		{
			echo "Bulk User: Temporary block due to high server load\n";
			exit;
		}
	}

	$oDB =& getDB();
	ini_set('memory_limit', '200M');

	// Format for output
	$sOutputFormat = 'xml';
	if (isset($_GET['format']) && ( $_GET['format'] == 'html' || $_GET['format'] == 'xml' || $_GET['format'] == 'json' || $_GET['format'] == 'jsonv2'))
	{
		$sOutputFormat = $_GET['format'];
	}

	// Preferred language
	$aLangPrefOrder = getPreferredLanguages();

	$hLog = logStart($oDB, 'reverse', $_SERVER['QUERY_STRING'], $aLangPrefOrder);

	if (isset($_GET['osm_type']) && isset($_GET['osm_id']) && (int)$_GET['osm_id'] && ($_GET['osm_type'] == 'N' || $_GET['osm_type'] == 'W' || $_GET['osm_type'] == 'R'))
	{
		$aLookup = array('osm_type' => $_GET['osm_type'], 'osm_id' => $_GET['osm_id']);
	}
	else if (isset($_GET['lat']) && isset($_GET['lon']) && preg_match('/^[+-]?[0-9]*\.?[0-9]+$/', $_GET['lat']) && preg_match('/^[+-]?[0-9]*\.?[0-9]+$/', $_GET['lon']))
	{
		$oReverseGeocode = new ReverseGeocode($oDB);
		$oReverseGeocode->setLanguagePreference($aLangPrefOrder);

		$oReverseGeocode->setLatLon($_GET['lat'], $_GET['lon']);
		$oReverseGeocode->setZoom(@$_GET['zoom']);
                $oReverseGeocode->setOsmType($_GET['osm_type']);
		
		$aLookup = $oReverseGeocode->lookup();
		if (CONST_Debug) var_dump($aLookup);
	}
	else
	{
		$aLookup = null;
	}


	if ($aLookup)
	{
		$oPlaceLookup = new PlaceLookup($oDB);
		$oPlaceLookup->setLanguagePreference($aLangPrefOrder);
		$oPlaceLookup->setIncludeAddressDetails(getParamBool('addressdetails', true));
		$oPlaceLookup->setIncludeExtraTags(getParamBool('extratags', false));
		$oPlaceLookup->setIncludeNameDetails(getParamBool('namedetails', false));

		$aPlace = $oPlaceLookup->lookupPlace($aLookup);
	}
	else
	{
		$aPlace = null;
	}


	if (CONST_Debug)
	{
		var_dump($aPlace);
		exit;
	}

	if ($sOutputFormat=='html')
	{
		$sDataDate = $oDB->getOne("select TO_CHAR(lastimportdate - '2 minutes'::interval,'YYYY/MM/DD HH24:MI')||' GMT' from import_status limit 1");
		$sTileURL = CONST_Map_Tile_URL;
		$sTileAttribution = CONST_Map_Tile_Attribution;
	}
	include(CONST_BasePath.'/lib/template/address-'.$sOutputFormat.'.php');
