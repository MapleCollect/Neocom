select sql || ";" from sqlite_master where tbl_name IN (
"crtCategories",
"crtCertificates",
"crtClasses",
"crtRecommendations",
"crtRelationships",
"dgmAttributeCategories",
"dgmAttributeTypes",
"dgmEffects",
"dgmTypeAttributes",
"dgmTypeEffects",
--"eveIcons",
"eveUnits",
"invBlueprintTypes",
"invCategories",
"invControlTowerResourcePurposes",
"invControlTowerResources",
"invGroups",
"invMarketGroups",
"invMetaGroups",
"invMetaTypes",
"invTypes",
"invTypeMaterials",
"mapConstellations",
"mapDenormalize",
"mapRegions",
"mapSolarSystems",
"ramActivities",
"ramAssemblyLineTypes",
"ramInstallationTypeContents",
"ramTypeRequirements",
"staStations");