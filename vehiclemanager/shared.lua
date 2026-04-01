VehicleManager = VehicleManager or {}
VehicleManager.Config = {
    menu = {
        keybindCommand = "+vehiclemanager_menu",
        defaultKey = "F5",
    },
    save = {
        ownerIdentifierPrefixes = { "license:", "license2:", "fivem:", "steam:", "discord:" },
    },
    appearance = {
        baseGlossColorOptions = {
            { label = "Black", colorId = 0 }, { label = "Carbon Black", colorId = 147 }, { label = "Graphite", colorId = 1 }, { label = "Anthracite Black", colorId = 11 }, { label = "Silver", colorId = 4 }, { label = "Blue Silver", colorId = 5 }, { label = "Rolled Steel", colorId = 6 }, { label = "Shadow Silver", colorId = 7 }, { label = "Stone Silver", colorId = 8 }, { label = "Midnight Silver", colorId = 9 }, { label = "Cast Iron Silver", colorId = 10 }, { label = "Red", colorId = 27 }, { label = "Torino Red", colorId = 28 }, { label = "Formula Red", colorId = 29 }, { label = "Lava Red", colorId = 150 }, { label = "Blaze Red", colorId = 30 }, { label = "Grace Red", colorId = 31 }, { label = "Garnet Red", colorId = 32 }, { label = "Sunset Red", colorId = 33 }, { label = "Cabernet Red", colorId = 34 }, { label = "Wine Red", colorId = 143 }, { label = "Candy Red", colorId = 35 }, { label = "Sunrise Orange", colorId = 36 }, { label = "Classic Gold", colorId = 37 }, { label = "Orange", colorId = 38 }, { label = "Dark Green", colorId = 49 }, { label = "Racing Green", colorId = 50 }, { label = "Sea Green", colorId = 51 }, { label = "Olive Green", colorId = 52 }, { label = "Bright Green", colorId = 53 }, { label = "Gasoline Green", colorId = 54 }, { label = "Lime Green", colorId = 92 }, { label = "Midnight Blue", colorId = 141 }, { label = "Galaxy Blue", colorId = 61 }, { label = "Dark Blue", colorId = 62 }, { label = "Saxon Blue", colorId = 63 }, { label = "Blue", colorId = 64 }, { label = "Mariner Blue", colorId = 65 }, { label = "Harbor Blue", colorId = 66 }, { label = "Diamond Blue", colorId = 67 }, { label = "Surf Blue", colorId = 68 }, { label = "Nautical Blue", colorId = 69 }, { label = "Racing Blue", colorId = 73 }, { label = "Ultra Blue", colorId = 70 }, { label = "Light Blue", colorId = 74 }, { label = "Chocolate Brown", colorId = 96 }, { label = "Bison Brown", colorId = 101 }, { label = "Creek Brown", colorId = 95 }, { label = "Feltzer Brown", colorId = 94 }, { label = "Maple Brown", colorId = 97 }, { label = "Beechwood Brown", colorId = 103 }, { label = "Sienna Brown", colorId = 104 }, { label = "Saddle Brown", colorId = 98 }, { label = "Moss Brown", colorId = 100 }, { label = "Woodbeech Brown", colorId = 102 }, { label = "Straw Brown", colorId = 99 }, { label = "Sandy Brown", colorId = 105 }, { label = "Bleached Brown", colorId = 106 }, { label = "Schafter Purple", colorId = 71 }, { label = "Spinnaker Purple", colorId = 72 }, { label = "Midnight Purple", colorId = 142 }, { label = "Bright Purple", colorId = 145 }, { label = "Cream", colorId = 107 }, { label = "Ice White", colorId = 111 }, { label = "Frost White", colorId = 112 }, { label = "Yellow", colorId = 88 }, { label = "Race Yellow", colorId = 89 }, { label = "Bronze", colorId = 90 }, { label = "Dew Yellow", colorId = 91 },
        },
        matteColorOptions = {
            { label = "Matte Black", colorId = 12 }, { label = "Matte Gray", colorId = 13 }, { label = "Matte Light Gray", colorId = 14 }, { label = "Matte Ice White", colorId = 131 }, { label = "Matte Blue", colorId = 83 }, { label = "Matte Dark Blue", colorId = 82 }, { label = "Matte Midnight Blue", colorId = 84 }, { label = "Matte Midnight Purple", colorId = 149 }, { label = "Matte Schafter Purple", colorId = 148 }, { label = "Matte Red", colorId = 39 }, { label = "Matte Dark Red", colorId = 40 }, { label = "Matte Orange", colorId = 41 }, { label = "Matte Yellow", colorId = 42 }, { label = "Matte Lime Green", colorId = 55 }, { label = "Matte Green", colorId = 128 }, { label = "Matte Forest Green", colorId = 151 }, { label = "Matte Foliage Green", colorId = 155 }, { label = "Matte Olive Drab", colorId = 152 }, { label = "Matte Dark Earth", colorId = 153 }, { label = "Matte Desert Tan", colorId = 154 },
        },
        utilColorOptions = {
            { label = "Util Black", colorId = 15 }, { label = "Util Black Poly", colorId = 16 }, { label = "Util Dark Silver", colorId = 17 }, { label = "Util Silver", colorId = 18 }, { label = "Util Gun Metal", colorId = 19 }, { label = "Util Shadow Silver", colorId = 20 }, { label = "Util Red", colorId = 43 }, { label = "Util Bright Red", colorId = 44 }, { label = "Util Garnet Red", colorId = 45 }, { label = "Util Dark Green", colorId = 56 }, { label = "Util Green", colorId = 57 }, { label = "Util Dark Blue", colorId = 75 }, { label = "Util Midnight Blue", colorId = 76 }, { label = "Util Blue", colorId = 77 }, { label = "Util Sea Foam Blue", colorId = 78 }, { label = "Util Lightning Blue", colorId = 79 }, { label = "Util Maui Blue Poly", colorId = 80 }, { label = "Util Bright Blue", colorId = 81 }, { label = "Util Brown", colorId = 108 }, { label = "Util Medium Brown", colorId = 109 }, { label = "Util Light Brown", colorId = 110 },
        },
        wornColorOptions = {
            { label = "Worn Black", colorId = 21 }, { label = "Worn Graphite", colorId = 22 }, { label = "Worn Silver Gray", colorId = 23 }, { label = "Worn Silver", colorId = 24 }, { label = "Worn Blue Silver", colorId = 25 }, { label = "Worn Shadow Silver", colorId = 26 }, { label = "Worn Red", colorId = 46 }, { label = "Worn Golden Red", colorId = 47 }, { label = "Worn Dark Red", colorId = 48 }, { label = "Worn Dark Green", colorId = 58 }, { label = "Worn Green", colorId = 59 }, { label = "Worn Sea Wash", colorId = 60 }, { label = "Worn Dark Blue", colorId = 85 }, { label = "Worn Blue", colorId = 86 }, { label = "Worn Light Blue", colorId = 87 }, { label = "Worn Honey Beige", colorId = 113 }, { label = "Worn Brown", colorId = 114 }, { label = "Worn Dark Brown", colorId = 115 }, { label = "Worn Straw Beige", colorId = 116 }, { label = "Worn Off White", colorId = 121 }, { label = "Worn Orange", colorId = 123 }, { label = "Worn Light Orange", colorId = 124 },
        },
        metalColorOptions = {
            { label = "Brushed Steel", colorId = 117 }, { label = "Brushed Black Steel", colorId = 118 }, { label = "Brushed Aluminium", colorId = 119 }, { label = "Pure Gold", colorId = 158 }, { label = "Brushed Gold", colorId = 159 },
        },
        chromeColorOptions = {
            { label = "Chrome", colorId = 120 },
        },
        xenonColorOptions = {
            { label = "Default", colorId = 255 }, { label = "White", colorId = 0 }, { label = "Blue", colorId = 1 }, { label = "Electric Blue", colorId = 2 }, { label = "Mint Green", colorId = 3 }, { label = "Lime Green", colorId = 4 }, { label = "Yellow", colorId = 5 }, { label = "Golden Shower", colorId = 6 }, { label = "Orange", colorId = 7 }, { label = "Red", colorId = 8 }, { label = "Pony Pink", colorId = 9 }, { label = "Hot Pink", colorId = 10 }, { label = "Purple", colorId = 11 }, { label = "Blacklight", colorId = 12 },
        },
        paintCategories = {
            { key = "classic", label = "Classic", paintType = 0, colorSet = "baseGlossColorOptions" },
            { key = "metallic", label = "Metallic", paintType = 1, colorSet = "baseGlossColorOptions" },
            { key = "matte", label = "Matte", paintType = 3, colorSet = "matteColorOptions" },
            { key = "util", label = "Util", paintType = 0, colorSet = "utilColorOptions" },
            { key = "worn", label = "Worn", paintType = 0, colorSet = "wornColorOptions" },
            { key = "metal", label = "Metal", paintType = 4, colorSet = "metalColorOptions" },
            { key = "chrome", label = "Chrome", paintType = 5, colorSet = "chromeColorOptions" },
        },
    },
    categories = {
        partsVehicleModCategories = {
            { modType = 0, label = "Spoilers" }, { modType = 1, label = "Front Bumper" }, { modType = 2, label = "Rear Bumper" }, { modType = 3, label = "Side Skirt" }, { modType = 4, label = "Exhaust" }, { modType = 5, label = "Frame" }, { modType = 6, label = "Grille" }, { modType = 7, label = "Hood" }, { modType = 8, label = "Left Fender" }, { modType = 9, label = "Right Fender" }, { modType = 10, label = "Roof" }, { modType = 14, label = "Horns" }, { modType = 25, label = "Plate Holders" }, { modType = 26, label = "Vanity Plates" }, { modType = 27, label = "Trim A" }, { modType = 28, label = "Ornaments" }, { modType = 29, label = "Dashboard" }, { modType = 30, label = "Dial" }, { modType = 31, label = "Door Speaker" }, { modType = 32, label = "Seats" }, { modType = 33, label = "Steering Wheel" }, { modType = 34, label = "Shifter" }, { modType = 35, label = "Plaques" }, { modType = 36, label = "Speakers" }, { modType = 37, label = "Trunk" }, { modType = 38, label = "Hydraulics" }, { modType = 39, label = "Engine Block" }, { modType = 40, label = "Air Filter" }, { modType = 41, label = "Struts" }, { modType = 42, label = "Arch Cover" }, { modType = 43, label = "Aerials" }, { modType = 44, label = "Trim B" }, { modType = 45, label = "Tank" }, { modType = 46, label = "Windows" },
        },
        statsVehicleModCategories = {
            { modType = 11, label = "Engine" }, { modType = 12, label = "Brakes" }, { modType = 13, label = "Transmission" }, { modType = 15, label = "Suspension" }, { modType = 16, label = "Armor" },
        },
        wheelCategories = {
            { wheelType = 0, label = "Sport" }, { wheelType = 1, label = "Muscle" }, { wheelType = 2, label = "Lowrider" }, { wheelType = 3, label = "SUV" }, { wheelType = 4, label = "Offroad" }, { wheelType = 5, label = "Tuner" }, { wheelType = 6, label = "Bike" }, { wheelType = 7, label = "High End" }, { wheelType = 8, label = "Benny's Original" }, { wheelType = 9, label = "Benny's Bespoke" }, { wheelType = 10, label = "Open Wheel" }, { wheelType = 11, label = "Street" }, { wheelType = 12, label = "Track" },
        },
    },
}
