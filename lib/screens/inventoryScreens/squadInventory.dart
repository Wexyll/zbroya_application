import 'dart:convert';

import 'package:animated_snack_bar/animated_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:getwidget/components/list_tile/gf_list_tile.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:zboryar_application/constants/constants.dart';
import 'package:zboryar_application/database/hive/model/invWeapon.dart';
import 'package:grouped_list/grouped_list.dart';

import '../../components/components.dart';
import '../../database/hive/model/boxes.dart';
import '../../database/hive/model/squadWeapon.dart';
import '../../database/storage.dart';

class squadInventory extends StatefulWidget {
  const squadInventory({Key? key}) : super(key: key);

  @override
  State<squadInventory> createState() => _squadInventoryState();
}

class _squadInventoryState extends State<squadInventory> {
  String caliberDropDown = '9x19mm NATO';
  List caliberList = [];
  List categoriesList = [];
  String? username;
  String dropDownValue = 'Sniper';
  bool isWeaponFromInventory = false;
  final _editingFormKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController sNumController = TextEditingController();
  final TextEditingController caliberController = TextEditingController();
  final TextEditingController soldierController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getCategories();
    getUser();
    getCalibers();
  }

  @override
  void dispose() {
    super.dispose();
    nameController.dispose();
    typeController.dispose();
    sNumController.dispose();
    caliberController.dispose();
    soldierController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Squad Inventory"),
        backgroundColor: bg_login,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 75),
        child: ValueListenableBuilder<Box>(
          valueListenable: Boxes.getSquadWeapons().listenable(),
          builder: (context, box, _) {
            final weaponsList = box.values.toList().cast<squadWeapon>();
            return buildSquadInventoryList(weaponsList);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await addWeaponDialog();
        },
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 55,
        ),
        backgroundColor: bg_login,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // drawer: const NavigationDrawer(),
    );
  }

  /*
  *
  * BUILD CONTENT
  *
   */

  Widget buildSquadInventoryList(List<squadWeapon> weaponsList) {
    if (weaponsList.isEmpty) {
      return Center(
        child: Text(
          'No Weapons Added Yet',
          style: TextStyle(fontSize: 24),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: GroupedListView(
          shrinkWrap: true,
          elements: weaponsList,
          groupBy: (singleWeapon) => singleWeapon.Type,
          order: GroupedListOrder.ASC,
          useStickyGroupSeparators: true,
          groupSeparatorBuilder: (String value) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          itemBuilder: (c, singleWeapon) {
            return Dismissible(
              background: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  color: Colors.red,
                ),
              ),
              confirmDismiss: (direction) => deleteDialog(context, direction),
              key: Key(singleWeapon.key.toString()),
              onDismissed: (direction) {
                singleWeapon.delete();
                ScaffoldMessenger.of(context).showSnackBar(
                    showSnackBar(context, '${singleWeapon.Name} dismissed'));
              },
              child: GFListTile(
                padding: EdgeInsets.all(15),
                margin: EdgeInsets.all(6),
                color: Colors.grey[400],
                titleText: '${singleWeapon.Name} - ID: ${singleWeapon.Soldier}',
                subTitleText: '${singleWeapon.Caliber}',
                description: Text('${singleWeapon.Serial_Number}'),
                icon: SvgPicture.asset(
                  "assets/icon/${singleWeapon.Type}.svg",
                  width: 35,
                  height: 32,
                ),
                onTap: () async {
                  await openEditWeaponDetailsDialog(singleWeapon);
                },
              ),
            );
          },
        ),
      );
    }
  }

  /*
  *
  *
  * FUNCTIONS START HERE
  *
  *
   */

  //Edit weapon modal
  openEditWeaponDetailsDialog(var weapon) => showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          soldierController.text = weapon.Soldier;
          nameController.text = weapon.Name;
          sNumController.text = weapon.Serial_Number;
          typeController.text = weapon.Type;
          caliberController.text = weapon.Caliber;
          return AlertDialog(
            title: Text("Edit Weapon"),
            content: Container(
              height: 350,
              width: 400,
              child: Form(
                key: _editingFormKey,
                child: ListView(
                  children: [
                    buildTextField(
                        textController: soldierController,
                        hintText: "${weapon.Soldier}"),
                    SizedBox(
                      height: 8,
                    ),
                    buildTextField(
                        textController: nameController,
                        hintText: "Weapon Name"),
                    SizedBox(
                      height: 8,
                    ),
                    buildTextField(
                        textController: sNumController,
                        hintText: "Weapon Serial Number"),
                    SizedBox(
                      height: 8,
                    ),
                    DropdownButton<String>(
                      items: [
                        for(String category in categoriesList) DropdownMenuItem<String>(value: category, child: Text(category)),
                      ],
                      value: weapon.Type,
                      onChanged: (value) => setState(() {
                        weapon.Type = value!;
                        typeController.text = value!;
                      }),
                    ),
                    SizedBox(height: 8),
                    DropdownButton<String>(
                      items: [
                        for(String caliber in caliberList) DropdownMenuItem<String>(value: caliber, child: Text(caliber)),
                      ],
                      value: weapon.Caliber,
                      onChanged: (value) => setState(() {
                        weapon.Caliber = value!;
                        caliberController.text = value!;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  if(_editingFormKey.currentState!.validate()) {
                    _editingFormKey.currentState!.save();
                    weapon.Name = nameController.text;
                    weapon.Soldier = soldierController.text;
                    weapon.Type = typeController.text;
                    weapon.Serial_Number = sNumController.text;
                    weapon.Caliber = caliberController.text;
                    weapon.save();
                    resetModalFields();
                    Navigator.pop(context);
                  }
                },
                child: Text("Okay"),
              ),
              TextButton(
                onPressed: () {
                  resetModalFields();
                  return Navigator.pop(context);
                },
                child: Text("Cancel"),
              ),
            ],
          );
        },
      );
    },
  );

  //Add weapon modal
  addWeaponDialog() => showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Add Weapon"),
              content: Container(
                height: 350,
                width: 400,
                child: Form(
                  key: _editingFormKey,
                  child: ListView(
                    children: [
                      buildTextField(
                          textController: soldierController,
                          hintText: "Soldier Assigned"),
                      SizedBox(
                        height: 8,
                      ),
                      buildTextField(
                          textController: nameController,
                          hintText: "Weapon Name"),
                      SizedBox(
                        height: 8,
                      ),
                      buildTextField(
                          textController: sNumController,
                          hintText: "Weapon Serial Number"),
                      SizedBox(
                        height: 8,
                      ),
                      DropdownButton<String>(
                        items: [
                          for(String category in categoriesList) DropdownMenuItem<String>(value: category, child: Text(category)),
                        ],
                        value: dropDownValue,
                        onChanged: (value) => setState(() {
                          dropDownValue = value!;
                          typeController.text = value!;
                        }),
                      ),
                      SizedBox(height: 8),
                      DropdownButton<String>(
                        items: [
                          for(String caliber in caliberList) DropdownMenuItem<String>(value: caliber, child: Text(caliber)),
                        ],
                        value: caliberDropDown,
                        onChanged: (value) => setState(() {
                          caliberDropDown = value!;
                          caliberController.text = value!;
                        }),
                      ),
                      CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text("Weapon From Inventory?"),
                          value: isWeaponFromInventory,
                          onChanged: (isWeaponFromInventory) => setState(() {
                                this.isWeaponFromInventory = isWeaponFromInventory!;
                              }))
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                  if(_editingFormKey.currentState!.validate()){
                      addSquadWeapon(
                          nameController.text,
                          dropDownValue,
                          caliberController.text,
                          sNumController.text,
                          soldierController.text,
                          username!);
                      showSnackBar(context, "Weapon Added");
                      if (isWeaponFromInventory == true) {
                        final box = Boxes.getWeapons();
                        final wpn = box.values.toList().cast<InventoryWeapon>();
                        for (int i = 0; i <= wpn.length - 1; i++) {
                          if (wpn[i].Name == nameController.text) {
                            if (wpn[i].Quantity > 1) {
                              wpn[i].Quantity = wpn[i].Quantity - 1;
                              wpn[i].save();
                            } else {
                              wpn[i].delete();
                            }
                          } else {
                            print("Weapon doesn't exist");
                          }
                        }
                      }
                      ;
                      resetModalFields();
                      isWeaponFromInventory = false;
                      Navigator.pop(context);
                    } else {
                      resetModalFields();
                      isWeaponFromInventory = false;
                      showSnackBar(context, 'No Weapons Added');
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Okay"),
                ),
                TextButton(
                  onPressed: () {
                    resetModalFields();
                    return Navigator.pop(context);
                  },
                  child: Text("Cancel"),
                ),
              ],
            );
          },
        );
      });

  //Hive add weapon functionality
  addSquadWeapon(String name, String type, String caliber, String sNum,
      String soldier, String user) async {
    final weapon = squadWeapon()
      ..Name = name
      ..Type = type
      ..Caliber = caliber
      ..Serial_Number = sNum
      ..Soldier = soldier
      ..User = user;

    final box = Boxes.getSquadWeapons();
    box.add(weapon);
  }

  //Getting categories of weapons from JSON
  Future getCategories() async {
    final String response = await rootBundle.loadString(
        'assets/json/categories.json');
    final data = await json.decode(response);
    categoriesList = data.toList();
  }

  //Resetting text controllers
  resetModalFields() {
    typeController.clear();
    soldierController.clear();
    nameController.clear();
    sNumController.clear();
    caliberController.clear();
    dropDownValue = 'Sniper';
  }

  //Getting currently logged in user
  Future<void> getUser() async {
    final StorageService _storageService = StorageService();
    username = (await _storageService.User())!;
  }

  //Get calibers of firearms
  Future getCalibers() async {
    final String response = await rootBundle.loadString(
        'assets/json/caliber.json');
    final data = await json.decode(response);
    caliberList = data.toList();
  }
}
