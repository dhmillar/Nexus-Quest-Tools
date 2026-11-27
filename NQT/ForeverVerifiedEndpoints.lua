-- CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/
-- Adapted from wow-completionist-data by Daniel Bates and contributors, and Warcraft Wiki contributors.
-- Pinned source: https://github.com/danielalanbates/wow-completionist-data/tree/64feae0e472c5b615e72e682ce470df03d485056
-- Selected endpoint identities cross-checked against live Forever quest metadata and normalized nearby observed
-- interactions or version-checked coordinates. Not native GPS. Sources for each selected row below.
-- Observed interactions: Efficient Games (https://efficient.games), CC BY 4.0.
local _,AT=...
AT.ForeverVerifiedEndpointReferences={
 -- Efficient Games first-hand observations: https://github.com/JIVESCORP/eg-link-output-wowf/tree/1339ce5600bbc2b12e8f1081e584f548f62fa57f/data/wowf
 [2747]={{1446,.5235,.2697,1,7763,0,"Curgle Cranklehop"}}, -- EG Link exact turn-in 1.60.1.71139
 [8893]={{1446,.5236,.2704,2,142071,0,"Egg-O-Matic"}}, -- EG Link exact turn-in 1.60.1.71091
 [5214]={{1423,.7088,.4859,1,11033,0,"Smokey LaRue"}}, -- EG Link exact turn-in 1.60.1.71139
 [5251]={{1423,.7159,.5004,1,11039,0,"Duke Nicholas Zverenhoff"}}, -- EG Link exact turn-in 1.60.1.71139
 [29]={{1450,.3651,.4026,1,11799,0,"Tajarri"}}, -- wiki quest rev 6230318; observed interaction
 [274]={{1432,.4601,.136,1,1093,1,"Chief Engineer Hinderweir VII"}}, -- wiki quest rev 6307981; observed interaction
 [283]={{1432,.4601,.136,1,1093,1,"Chief Engineer Hinderweir VII"}}, -- wiki quest rev 6307982; observed interaction
 [306]={{1437,.1143,.523,1,2096,1,"Tarrel Rockweaver"}}, -- wiki quest rev 6310546; interaction build 1.60.1.71037
 [309]={{1432,.6584,.6545,1,1344,1,"Prospector Ironband"}}, -- wiki quest rev 6476657; interaction build 1.60.1.70959
 [324]={{1437,.1062,.6049,1,1217,1,"Glorin Steelbrow"}}, -- wiki quest rev 5586899; observed interaction
 [343]={{1453,.7696,.3019,1,1440,1,"Milton Sheaf"}}, -- wiki quest rev 6297908; observed interaction
 [346]={{1453,.5507,.5428,1,1444,1,"Brother Kristoff"}}, -- wiki quest rev 6297913; interaction build 1.60.1.70938
 [414]={{1432,.3442,.4752,1,1340,1,"Mountaineer Kadrell"}}, -- wiki quest rev 5586613; interaction build 1.60.1.70959
 [436]={{1432,.6495,.6656,1,1345,1,"Magmar Fellhew"}}, -- wiki quest rev 6176745; interaction build 1.60.1.70959
 [521]={{1458,.5736,.9393,1,2227,2,"Sharlindra"}}, -- wiki quest rev 5627640; interaction build 1.60.1.71037
 [592]={{1434,.3216,.278,1,2497,2,"Nimboya"}}, -- wiki quest rev 6726060; observed interaction
 [618]={{1434,.2672,.7366,1,2500,0,"Captain Hecklebury Smotts"}}, -- wiki quest rev 6921026; observed interaction
 [640]={{1417,.7469,.3647,1,2706,2,"Tor'gan"}}, -- wiki quest rev 5633767; observed interaction
 [641]={{1417,.7385,.339,1,2703,2,"Zengu"}}, -- wiki quest rev 5633771; observed interaction
 [643]={{1417,.7385,.339,1,2703,2,"Zengu"}}, -- wiki quest rev 5633772; observed interaction
 [646]={{1417,.7385,.339,1,2703,2,"Zengu"}}, -- wiki quest rev 5633774; observed interaction
 [656]={{1417,.6239,.3376,2,138492,0,"Shards of Myzrael"}}, -- wiki quest rev 5636131; interaction build 1.60.1.71037
 [657]={{1417,.6,.53,1,2713,1,"Kinelory"}}, -- wiki quest rev 5586085, location rev 6891482
 [660]={{1417,.601,.5381,1,2712,1,"Quae"}}, -- wiki quest rev 6305548; observed interaction
 [707]={{1432,.6584,.6545,1,1344,1,"Prospector Ironband"}}, -- wiki quest rev 6930304; interaction build 1.60.1.70959
 [727]={{1455,.5071,.0612,1,2786,1,"Gerrig Bonegrip"}}, -- wiki quest rev 5636502; observed interaction
 [739]={{1432,.6584,.6545,1,1344,1,"Prospector Ironband"}}, -- wiki quest rev 6930305; interaction build 1.60.1.70959
 [847]={{1417,.7469,.3647,1,2706,2,"Tor'gan"}}, -- wiki quest rev 6960271; observed interaction
 [939]={{1448,.5133,.8157,1,9116,1,"Eridan Bluewind"}}, -- wiki quest rev 5747744; interaction build 1.60.1.71037
 [948]={{1439,.436,.764,1,3616,1,"Onu"}}, -- wiki quest rev 6577003, location rev 6943471
 [950]={{1439,.436,.764,1,3616,1,"Onu"}}, -- wiki quest rev 6595157, location rev 6943471
 [952]={{1439,.436,.764,1,3616,1,"Onu"}}, -- wiki quest rev 6176660, location rev 6943471
 [1040]={{1434,.2736,.7414,1,3945,1,"Caravaneer Ruzzgot"}}, -- wiki quest rev 6230105; observed interaction
 [1091]={{1442,.5987,.6688,1,4080,1,"Kaela Shadowspear"}}, -- wiki quest rev 6306791; observed interaction
 [1123]={{1450,.5167,.4485,1,11801,2,"Rabine Saturna"}}, -- wiki quest rev 6895634; interaction build 1.60.1.71091
 [1261]={{1445,.3526,.3076,1,4791,2,"Nazeer Bloodpike"}}, -- wiki quest rev 6839809; observed interaction
 [1382]={{1443,.3631,.7928,1,5397,1,"Uthek the Wise"}}, -- wiki quest rev 5586614; observed interaction
 [1484]={{1443,.5261,.5429,1,5641,2,"Takata Steelblade"}}, -- wiki quest rev 6308734; observed interaction
 [1520]={{1411,.4413,.7618,1,5891,2,"Minor Manifestation of Earth"}}, -- wiki quest rev 6896599; observed interaction
 [1532]={{1441,.5358,.4278,1,5905,2,"Prate Cloudseer"}}, -- wiki quest rev 6896601; observed interaction
 [1799]={{1445,.4602,.5717,1,6546,0,"Tabetha"}}, -- wiki quest rev 6230025; observed interaction
 [1841]={{1458,.6239,.3947,1,6411,2,"Velora Nitely"}}, -- wiki quest rev 5587168; interaction build 1.60.1.70938
 [1883]={{1411,.5624,.751,1,5880,2,"Un'Thuwa"}}, -- wiki quest rev 6334294; interaction build 1.60.1.71037
 [1898]={{1458,.5455,.7577,1,6522,2,"Andron Gant"}}, -- wiki quest rev 5638469; interaction build 1.60.1.71091
 [1951]={{1445,.4602,.5717,1,6546,0,"Tabetha"}}, -- wiki quest rev 6720103; observed interaction
 [2318]={{1418,.0259,.4616,1,6868,2,"Jarkal Mossmeld"}}, -- wiki quest rev 6258219; observed interaction
 [2341]={{1418,.0259,.4616,1,6868,2,"Jarkal Mossmeld"}}, -- wiki quest rev 6258227; observed interaction
 [2759]={{1434,.2884,.7543,1,7794,1,"McGavan"}}, -- wiki quest rev 6840773; observed interaction
 [2860]={{1456,.4164,.4271,1,3007,2,"Una"}}, -- wiki quest rev 6351050; interaction build 1.60.1.70888
 [2876]={{1446,.6703,.2392,1,7882,0,"Security Chief Bilgewhizzle"}}, -- wiki quest rev 6277679; observed interaction
 [2937]={{1424,.6151,.1919,1,2216,2,"Apothecary Lydon"}}, -- wiki quest rev 6429434; observed interaction
 [2985]={{1413,.6579,.4377,1,5901,2,"Islen Waterseer"}}, -- wiki quest rev 6175739; observed interaction
 [3065]={{1411,.4291,.6938,1,3153,2,"Frang"}}, -- wiki quest rev 6873058; observed interaction
 [3087]={{1411,.429,.6927,1,3154,2,"Jen'shan"}}, -- wiki quest rev 6022216; observed interaction
 [3088]={{1411,.413,.6807,1,3155,2,"Rwag"}}, -- wiki quest rev 6176543; observed interaction
 [3089]={{1411,.4241,.6903,1,3157,2,"Shikrik"}}, -- wiki quest rev 6022214; observed interaction
 [3090]={{1411,.4063,.6844,1,3156,2,"Nartok"}}, -- wiki quest rev 6296518; observed interaction
 [3119]={{1438,.5917,.4049,1,3595,1,"Shanda"}}, -- wiki quest rev 5887937; interaction build 1.60.1.70790
 [3542]={{1458,.5455,.7577,1,6522,2,"Andron Gant"}}, -- wiki quest rev 6237226; interaction build 1.60.1.71091
 [3562]={{1447,.2253,.5136,1,8587,2,"Jediga"}}, -- wiki quest rev 6237216; interaction build 1.60.1.71037
 [3563]={{1447,.2253,.5136,1,8587,2,"Jediga"}}, -- wiki quest rev 6237210; interaction build 1.60.1.71037
 [3564]={{1447,.2253,.5136,1,8587,2,"Jediga"}}, -- wiki quest rev 6237227; interaction build 1.60.1.71037
 [3565]={{1447,.2253,.5136,1,8587,2,"Jediga"}}, -- wiki quest rev 6237222; interaction build 1.60.1.71037
 [3765]={{1439,.3834,.4306,1,8997,1,"Gershala Nightwhisper"}}, -- wiki quest rev 6055964; interaction build 1.60.1.70959
 [3914]={{1449,.4467,.0829,1,8737,0,"Linken"}}, -- wiki quest rev 5627732; observed interaction
 [3941]={{1449,.4184,.0258,1,9117,0,"J.D. Collie"}}, -- wiki quest rev 5631621; observed interaction
 [3942]={{1448,.5133,.8157,1,9116,0,"Eridan Bluewind"}}, -- wiki quest rev 5632941; interaction build 1.60.1.71037
 [3961]={{1449,.4467,.0829,1,8737,0,"Linken"}}, -- wiki quest rev 5632948; observed interaction
 [4005]={{1449,.4184,.0258,1,9117,0,"J.D. Collie"}}, -- wiki quest rev 6164598; observed interaction
 [4245]={{1449,.4635,.1357,1,9618,0,"Karna Remtravel"}}, -- wiki quest rev 5619969; interaction build 1.60.1.71037
 [4765]={{1453,.7709,.4759,1,2285,1,"Count Remington Ridgewell"}}, -- wiki quest rev 6905612; interaction build 1.60.1.70959
 [4987]={{1456,.7554,.3162,1,5770,2,"Nara Wildmane"}}, -- wiki quest rev 6950471; observed interaction
 [5047]={{1452,.6097,.3875,1,10637,0,"Malyfous Darkhammer"}}, -- wiki quest rev 6508298; interaction build 1.60.1.71037
 [5103]={{1452,.6097,.3875,1,10637,0,"Malyfous Darkhammer"}}, -- wiki quest rev 6176700; interaction build 1.60.1.71037
 [5635]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 6316434; observed interaction
 [5636]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 6316435; observed interaction
 [5637]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 6316433; observed interaction
 [5638]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 6316438; observed interaction
 [5639]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 6316436; observed interaction
 [5640]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 6316437; observed interaction
 [5677]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 5809430; observed interaction
 [5678]={{1453,.4947,.4478,1,376,1,"High Priestess Laurena"}}, -- wiki quest rev 5637211; observed interaction
 [5932]={{1456,.7645,.2774,1,3033,2,"Turak Runetotem"}}, -- wiki quest rev 5995217; observed interaction
 [5943]={{1443,.6089,.6187,1,11596,0,"Smeed Scrabblescrew"}}, -- wiki quest rev 5638379; observed interaction
 [6071]={{1438,.5667,.596,1,3601,1,"Dazalar"}}, -- wiki quest rev 6591431; observed interaction
 [6132]={{1443,.4782,.6179,1,6019,0,"Hornizz Brimbuzzle"}}, -- wiki quest rev 6349107; interaction build 1.60.1.70888
 [6362]={{1456,.4536,.5547,1,8359,2,"Ahanu"}}, -- wiki quest rev 6230349; interaction build 1.60.1.70862
 [6387]={{1432,.3387,.5089,1,1572,1,"Thorgrum Borrelson"}}, -- wiki quest rev 6314327; interaction build 1.60.1.70959
 [6603]={{1452,.3117,.4546,1,9298,0,"Donova Snowden"}}, -- wiki quest rev 6306113; observed interaction
 [6762]={{1450,.5167,.4485,1,11801,1,"Rabine Saturna"}}, -- wiki quest rev 5609753; interaction build 1.60.1.71091
 [6845]={{1450,.5167,.4485,1,11801,0,"Rabine Saturna"}}, -- wiki quest rev 5611825; interaction build 1.60.1.71091
 [6964]={{1454,.3887,.362,1,13417,2,"Sagorne Creststrider"}}, -- wiki quest rev 6566480; interaction build 1.60.1.70959
 [7905]={{1429,.4157,.6892,1,14828,1,"Gelvas Grimegate"}}, -- wiki quest rev 6707921; interaction build 1.60.1.70938
 [7926]={{1429,.4157,.6892,1,14828,2,"Gelvas Grimegate"}}, -- wiki quest rev 6708169; interaction build 1.60.1.70938
 [8151]={{1447,.4234,.4264,1,8405,0,"Ogtinc"}}, -- wiki quest rev 5608447; observed interaction
 [8181]={{1446,.6693,.224,1,8579,0,"Yeh'kinya"}}, -- wiki quest rev 6899497; observed interaction
 [8254]={{1447,.4234,.4264,1,8405,0,"Ogtinc"}}, -- wiki quest rev 5623980; observed interaction
 [8257]={{1448,.5121,.8248,1,10922,0,"Greta Mosshoof"}}, -- wiki quest rev 6878682; observed interaction
 [91858]={{1421,.4339,.4105,1,248840,2,"Trevan Rol"}}, -- wiki quest rev 6963528; observed interaction
 [92482]={{2521,.4251,.2377,1,251376,0,"Tai'ree Farsight"}}, -- wiki quest rev 6889618; interaction build 1.60.1.70938
 [94436]={{1420,.2195,.4457,1,257655,2,"Deathguard Billmuth"}}, -- wiki quest rev 6908617; interaction build 1.60.1.70959
 [94440]={{1420,.2195,.4457,1,257655,2,"Deathguard Billmuth"}}, -- wiki quest rev 6967132; interaction build 1.60.1.70959
 [96408]={{1426,.6486,.5845,1,264936,1,"Earthseer Farsen"}}, -- wiki quest rev 6964448; observed interaction
 [98576]={{1411,.4252,.69,1,5884,2,"Mai'ah"}}, -- wiki quest rev 6908630; observed interaction
 -- Observed quest-reward windows with stable normalized positions, from Efficient Games (CC BY 4.0).
 -- https://github.com/JIVESCORP/eg-link-output-wowf/blob/main/DATASETS.md#npcs
 [702]={{1417,0.7268,0.3404,1,2792,2,"Gor'mul"}}, -- Forever takes 1.60.1.71091
 [2621]={{1435,0.4789,0.5503,1,7623,2,"Dispatch Commander Ruag"}}, -- Forever takes 1.60.1.71091
 [2622]={{1435,0.4499,0.5714,1,7643,2,"Bengor"}}, -- Forever takes 1.60.1.71091
 [2767]={{1434,0.2835,0.7626,1,7406,0,"Oglethorpe Obnoticus"}}, -- Forever takes 1.60.1.71091
 [2784]={{1435,0.3425,0.6599,1,7572,0,"Fallen Hero of the Horde"}}, -- Forever takes 1.60.1.71091
 [4300]={{1454,0.5557,0.3418,1,8659,2,"Jes'rimon"}}, -- Forever takes 1.60.1.71091
 [5405]={{1420,0.8313,0.685,1,10839,0,"Argent Officer Garush"}}, -- Forever takes 1.60.1.71139
 [7441]={{1444,0.7696,0.3738,1,14355,0,"Azj'Tordin"}}, -- Forever takes 1.60.1.71139
 [83934]={{1434,0.2848,0.7586,1,227853,0,"Pix Xizzix"}}, -- Forever takes 1.60.1.71139
 [84402]={{1458,0.7348,0.3267,1,7825,2,"Oran Snakewrithe"}}, -- Forever takes 1.60.1.71139
 [93971]={{2548,.594,.4573,1,256418,2,"Krom'rosh"}}, -- exact Forever quest recipient observed by AHledger, position from EG interactions
 [93568]={{2652,0.4732,0.6567,1,255385,0,"Liranne"}}, -- Forever takes 1.60.1.71091, 1.60.1.71139
 [94613]={{2548,0.5487,0.7312,1,258317,1,"Benjy Wheeler"}}, -- Forever takes 1.60.1.71139
 -- Live ForeverDB hand-in and independently observed Forever Scout NPC; approximate reference, not native GPS.
 [94980]={{2548,.644,.820,1,259250,1,"Alphonse Dumas"}},
 [94614]={{2548,0.5487,0.7312,1,258317,1,"Benjy Wheeler"}}, -- Forever takes 1.60.1.71139
 [94615]={{2548,0.5487,0.7312,1,258317,1,"Benjy Wheeler"}}, -- Forever takes 1.60.1.71139
 [94678]={{2548,0.3956,0.7471,1,259353,1,"Cedric Dalton"}}, -- Forever takes 1.60.1.71139
 [94842]={{2548,0.4113,0.6294,1,256438,1,"Halligan Turner"}}, -- Forever takes 1.60.1.71139
 [94843]={{2548,0.4113,0.6294,1,256438,1,"Halligan Turner"}}, -- Forever takes 1.60.1.71139
 [94857]={{2548,0.4136,0.6448,1,258963,1,"Hurley"}}, -- Forever takes 1.60.1.71139
 [94861]={{2548,0.4113,0.6294,1,256438,1,"Halligan Turner"}}, -- Forever takes 1.60.1.71139
 [94877]={{2548,0.6658,0.81,1,257558,1,"Demar Brant"}}, -- Forever takes 1.60.1.71139
 [94879]={{2548,0.6672,0.8108,1,257591,1,"Ashe Amberhall"}}, -- Forever takes 1.60.1.71139
 [94885]={{2548,0.6658,0.81,1,257558,1,"Demar Brant"}}, -- Forever takes 1.60.1.71139
 [94923]={{2548,0.4339,0.8268,1,259049,1,"Robbie Holmsby"}}, -- Forever takes 1.60.1.71139
 [94924]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [94925]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [94931]={{2548,0.4113,0.6294,1,256438,1,"Halligan Turner"}}, -- Forever takes 1.60.1.71139
 [94999]={{2548,0.3641,0.758,1,259051,1,"Watcher Fredericks"}}, -- Forever takes 1.60.1.71139
 [95064]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [95066]={{2548,0.6658,0.81,1,257558,1,"Demar Brant"}}, -- Forever takes 1.60.1.71139
 [95147]={{2548,0.3956,0.7471,1,259353,1,"Cedric Dalton"}}, -- Forever takes 1.60.1.71139
 [95148]={{2548,0.6658,0.81,1,257558,1,"Demar Brant"}}, -- Forever takes 1.60.1.71139
 [95156]={{2548,0.6612,0.7958,1,260080,1,"Ember Bladewhisper"}}, -- Forever takes 1.60.1.71139
 [95329]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [95330]={{2548,0.4113,0.6294,1,256438,1,"Halligan Turner"}}, -- Forever takes 1.60.1.71139
 [95426]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [95561]={{2548,0.6383,0.8233,1,263089,1,"Tessa Dawnbright"}}, -- Forever takes 1.60.1.71139
 [95913]={{2548,0.6383,0.8233,1,263089,1,"Tessa Dawnbright"}}, -- Forever takes 1.60.1.71139
 [95961]={{2548,0.7883,0.5413,1,263120,1,"Gray Dawnbright"}}, -- Forever takes 1.60.1.71139
 [95983]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [95986]={{2548,0.5945,0.6394,1,259352,1,"Watcher Cornelius"}}, -- Forever takes 1.60.1.71139
 [95988]={{2548,0.7877,0.5411,1,255894,0,"Innkeeper Zizplink"}}, -- Forever takes 1.60.1.71139
 [96088]={{1434,0.2848,0.7586,1,227853,0,"Pix Xizzix"}}, -- Forever takes 1.60.1.71139
 -- Exact quest-recipient identities, observed at a stable spot in Forever.
 [2623]={{1435,.3425,.6599,1,7572,2,"Fallen Hero of the Horde"}}, -- wiki quest rev 6207148; interaction build 1.60.1.71091
 [2743]={{1435,.3425,.6599,1,7572,0,"Fallen Hero of the Horde"}}, -- wiki quest rev 5619898; interaction build 1.60.1.71091
 [2783]={{1435,.3425,.6599,1,7572,1,"Fallen Hero of the Horde"}}, -- wiki quest rev 5620187; interaction build 1.60.1.71091
 [3626]={{1435,.3425,.6599,1,7572,0,"Fallen Hero of the Horde"}}, -- wiki quest rev 5620074; interaction build 1.60.1.71091
 [5529]={{1423,.7158,.4989,1,11035,0,"Betina Bigglezink"}}, -- https://www.wowhead.com/forever/quest=5529/plagued-hatchlings ; exact NPC observed in 71139
 [5531]={{1423,.7158,.4989,1,11035,0,"Betina Bigglezink"}}, -- wiki quest rev 6296864; interaction build 1.60.1.71139
 [6029]={{1420,.8313,.685,1,10839,2,"Argent Officer Garush"}}, -- wiki quest rev 6351370; interaction build 1.60.1.71139
 [8417]={{1435,.3425,.6599,1,7572,0,"Fallen Hero of the Horde"}}, -- wiki quest rev 5995133; interaction build 1.60.1.71091
}

-- Area-only turn-in references: no coordinates are inferred for instance floors,
-- movable escorts, or scripted encounters. Existing native pins still win.
-- Only the actual recipient is listed, never the quest giver as a proxy.
-- Original source attribution above; cross-checks: https://www.wowhead.com/forever/
AT.ForeverTurnInAreaReferences={
 [1098]={"Shadowfang Keep","Deathstalker Vincent",true,2}, -- wiki rev 6956883
 [1144]={"Razorfen Kraul","Willix the Importer",true,0}, -- Forever quest 1144; escort NPC, not his cage
 [2278]={"Uldaman","Discs of Norgannon",false,0}, -- wiki rev 6554281
 [2945]={"Gnomeregan","Sparklematic 5200",false,0}, -- wiki rev 6523024
 [2951]={"Gnomeregan","The Sparklematic 5200",false,0}, -- wiki rev 6555985
 [2952]={"Gnomeregan","The Sparklematic 5200",false,0}, -- wiki rev 5720294
 [3373]={"Temple of Atal'Hakkar","Essence Font",false,0}, -- wiki rev 5970911
 [3446]={"Temple of Atal'Hakkar","Altar of Hakkar",false,0}, -- wiki rev 6568868
 [3447]={"Temple of Atal'Hakkar","Idol of Hakkar",false,0}, -- wiki rev 6568869
 [3523]={"Razorfen Downs","Belnistrasz",true,0}, -- wiki rev 6176957
 [3525]={"Razorfen Downs","Belnistrasz's Brazier",false,0}, -- wiki rev 6774622
 [4601]={"Gnomeregan","The Sparklematic 5200",false,0}, -- wiki rev 6555985
 [4604]={"Gnomeregan","The Sparklematic 5200",false,0}, -- Forever quest 4604
 [4605]={"Gnomeregan","The Sparklematic 5200",false,0}, -- wiki rev 5720294
 [5722]={"Ragefire Chasm","Maur Grimtotem",true,2}, -- wiki rev 6693422
 [7044]={"Maraudon","Celebras the Redeemed",true,0}, -- wiki rev 6219314
 [7046]={"Maraudon","Celebras the Redeemed",true,0}, -- wiki rev 6850700
 [7463]={"Dire Maul, the Athenaeum","Lorekeeper Lydros",true,0}, -- https://www.wowhead.com/forever/quest=7463/arcane-refreshment
 [96395]={"The Hall of Thanes","Ghostly Attendant",true,0}, -- wiki rev 6937497; Forever quest 96395
 [96987]={"Dalaran, near the sewer entrance","Rexxie Copperclutch",true,2}, -- wiki rev 6937495; Forever quest 96987
 [2953]={"Gnomeregan","The Sparklematic 5200",false,0}, -- https://www.wowhead.com/forever/quest=2953/more-sparklematic-action
 [4603]={"Gnomeregan","The Sparklematic 5200",false,0}, -- https://www.wowhead.com/forever/quest=4603/more-sparklematic-action
 [95309]={"Alcaz Prison","Commander Folkar",true,2}, -- https://warcraft.wiki.gg/wiki/No_Orc_Left_Behind_(Alcaz_Prison)
 [96335]={"Alcaz Prison","Mason Connery",true,0}, -- https://warcraft.wiki.gg/wiki/The_Man_in_the_Iron_Chains
 [96369]={"Alcaz Prison","Commander Folkar",true,2}, -- https://warcraft.wiki.gg/wiki/Bad_News_for_Folkar
}
