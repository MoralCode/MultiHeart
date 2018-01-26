//
//  ViewController.swift
//  MultiHeart
//
//  Created by ACE on 1/22/18.
//  Copyright © 2018 Adrian Edwards. All rights reserved.
//

import UIKit
import CoreBluetooth

enum DeviceStatus: Int {
    case disconnected = 0
    case connecting = 1
    case connected = 2
}
let heartRateServiceCBUUID = CBUUID(string: "0x180D")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")


class ViewController: UITableViewController{
    
    var centralManager: CBCentralManager?
    var deviceList = Array<(nickname: String, device: CBPeripheral, lastHR: Int)>()
    
    var shouldRefresh: Bool = true
    
    func startSearchingForHeartRateDevices(stopAfterSeconds: Double = 5.0) {
        print("Start Scanning...")
        centralManager?.scanForPeripherals(withServices: [heartRateServiceCBUUID])
        
        if (stopAfterSeconds > 0) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + stopAfterSeconds) {
                self.stopSearchingForHeartRateDevices()
            }
        }
        
    }
    
    func stopSearchingForHeartRateDevices(restartAfter: Double = 20.0) {
        print("Stop Scanning...")
        centralManager?.stopScan()
        
        if (restartAfter > 0) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + restartAfter) {
                self.startSearchingForHeartRateDevices()
            }
        }
    }
    
    func setNicknameForDeviceAtIndex(index: Int, nickname: String) {
        deviceList[index].nickname = nickname
    }
    
    
    func updateHRForDeviceAtIndex(index: Int, heartRate: Int) {
        deviceList[index].lastHR = heartRate
    }
    
    func doesDeviceListContain(peripheral: CBPeripheral) -> Bool {
    
        if (findInDeviceList(peripheral: peripheral) != -1) {
            return true
        } else {
            return false
        }
    }

    func findInDeviceList(peripheral: CBPeripheral) -> Int {
        var index = 0
        for device in deviceList {
            
            if (device.device == peripheral) {
                return index
            } else {
                index = index + 1
            }
            
        }
        //if it couldnt be found
        return -1
    }
    
    func getConnectedDevices() -> Array<(nickname: String, device: CBPeripheral, lastHR: Int)> {
        var connectedDevices:Array<(nickname: String, device: CBPeripheral, lastHR: Int)> = []
        for device in deviceList {
            if (device.device.state.rawValue == DeviceStatus.connected.rawValue) {
                connectedDevices.append(device)
            }
        }
        return connectedDevices
    }
    
    func refreshView(secondsUntilRepeat: Double = 1) {
        if (!tableView.isEditing && shouldRefresh){
            print("RELOADING DATA...")
            tableView.reloadData()//reloads all data
        }
        
        if (secondsUntilRepeat > 0) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + secondsUntilRepeat) {
                self.refreshView()
            }
        }
    }
    
    func blockRefreshes(){
        shouldRefresh = false
    }
    
    func unblockRefreshes(){
        shouldRefresh = true
    }

    func confirmDisconnect(indexPath: IndexPath, resetNickname:Bool = false) {
        let alert = UIAlertController(title: "Disconnect", message: "Are you sure you want to disconnect from '\(deviceList[indexPath[1]].nickname)'?", preferredStyle: .actionSheet)
        
        let disconnectAction = UIAlertAction(title: "Disconnect", style: .destructive, handler: {(alert: UIAlertAction!) in self.handleDisconnectDevice(indexPath: indexPath)})
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    
        alert.addAction(disconnectAction)
        alert.addAction(cancelAction)
        
        // Support display in iPad
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: 1.0, y: 1.0, width: self.view.bounds.size.width / 2.0, height: self.view.bounds.size.height / 2.0)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func handleDisconnectDevice(indexPath: IndexPath) {
        
        blockRefreshes()
        tableView.beginUpdates()

        
        
        //AAAAAAAL this just to unregister from notifications from a service before disconnecting. You're welcome apple.
        guard let services = deviceList[indexPath[1]].device.services else { return }

        for service in services {
            if (service.uuid == heartRateServiceCBUUID) {
                
                print("Service: " + String(describing: service))
                print("Service Characteristics: " + String(describing: service.characteristics))
                //deviceList[indexPath[1]].device.discoverCharacteristics(nil, for: service)
                
                guard let characteristics = service.characteristics else { return }
                
                for characteristic in characteristics {
                    if (characteristic.uuid == heartRateMeasurementCharacteristicCBUUID) {
                        //print("\(characteristic.uuid): properties contains .notify")
                        deviceList[indexPath[1]].device.setNotifyValue(false, for: characteristic) //HOLY CRAP. FINALLY WE GET DOWN DEEP ENOUGH TO GET WHAT WE NEED. BOI
                    }
                }
            }
        }
        
        //actually disconnect from the damn thing
        centralManager?.cancelPeripheralConnection(deviceList[indexPath[1]].device)
        
        tableView.endUpdates()
        unblockRefreshes()
    }
    
    func handleChangeNickname(indexPath: IndexPath) {
        let alert = UIAlertController(title: "Set Nickname", message: "Set the nickname for\n'\(deviceList[indexPath[1]].device.name!)'.", preferredStyle: .alert)
        
        
        alert.addTextField(configurationHandler: { textField -> Void in
            //configure textField before display
            textField.placeholder = self.deviceList[indexPath[1]].nickname
            
        })
        
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) {
            [weak alert] _ in
            if let alert = alert {
                let nicknameTextField = alert.textFields![0] as UITextField
                if let text = nicknameTextField.text {
                    if text != "" {
                        self.setNicknameForDeviceAtIndex(index: indexPath[1], nickname: text)
                    } else { //if text is blank
                        self.setNicknameForDeviceAtIndex(index: indexPath[1], nickname: self.deviceList[indexPath[1]].device.name!)
                    }
                } else {print("error1")}
            } else {print("error2")}
        }
        
        let resetAction = UIAlertAction(title: "Reset", style: .destructive) {
            [weak alert] _ in
            self.setNicknameForDeviceAtIndex(index: indexPath[1], nickname: self.deviceList[indexPath[1]].device.name!)
        }
        
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        alert.addAction(resetAction)
        
        
        // Support display in iPad
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: 1.0, y: 1.0, width: self.view.bounds.size.width / 2.0, height: self.view.bounds.size.height / 2.0)
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.tableView.register(DeviceCell.self, forCellReuseIdentifier: "deviceCell")
        
        tableView.allowsMultipleSelectionDuringEditing = false;
        
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 85.0
        tableView.rowHeight = UITableViewAutomaticDimension
        
        refreshView()//start the loop
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()//?
    }
    
    
    
    
    
    
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (deviceList.count == 0) {
            return 1;
        } else {
            //number of connected Devices
            return deviceList.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        //variable type is inferred
        let cell = tableView.dequeueReusableCell(withIdentifier: "deviceCell", for: indexPath) as! DeviceCell
        
        cell.selectionStyle = .none
        
        cell.nicknameLabel.font = UIFont.boldSystemFont(ofSize: 20)
        
        if (deviceList.count == 0) {
            cell.bpmLabel.text = "---"
            cell.nicknameLabel.text = ""
            cell.statusLabel.text = "Searching..."
            
        } else {
            
            cell.bpmLabel.text = String(describing: deviceList[indexPath[1]].lastHR)
            cell.nicknameLabel.text = deviceList[indexPath[1]].nickname
            
            switch (deviceList[indexPath[1]].device.state.rawValue) {
                case DeviceStatus.disconnected.rawValue:
                    cell.statusLabel.text = "Tap to connect..." //"disconnected"
                    cell.bpmLabel.text = "---"
                    break
                case DeviceStatus.connecting.rawValue:
                    cell.statusLabel.text = "Connecting..."//? not 100% sure if this is right
                    break
                case DeviceStatus.connected.rawValue:
                    cell.statusLabel.text = "Connected!"
                    break
                //disconnecting
                //deviceList.remove(at: index)
                default:
                    print(deviceList[indexPath[1]].device.state.rawValue)
                    cell.statusLabel.text = "other"
                    break
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (deviceList[indexPath[1]].device.state.rawValue) {
            case 0://disconnected
                centralManager?.connect(deviceList[indexPath[1]].device, options: nil)
                break
            case 1://connecting? maybe
                //nada
                break
            case 2: //connected
                //popup to change nickname
                handleChangeNickname(indexPath: indexPath)
                break
            default://other
                print(deviceList[indexPath[1]].device.state.rawValue)
                break
        }
    }
    
    
   
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let disconnect = UITableViewRowAction(style: .normal, title: "disconnect") {
            (action, indexPath) in
            self.confirmDisconnect(indexPath: indexPath)
        }
        return [disconnect]
    }
}











extension ViewController: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            startSearchingForHeartRateDevices(stopAfterSeconds: 45)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        if (!doesDeviceListContain(peripheral: peripheral)){//if peripheral doesnt already Exist
            
            peripheral.delegate = self
            let entry = (nickname: peripheral.name!, device: peripheral, lastHR: 0)
            deviceList.append(entry) //add it
        }
        refreshView(secondsUntilRepeat: 0)//force refresh without looping as soon as a new peripheral is discovered
    }
    
}





    
extension ViewController: CBPeripheralDelegate {
       
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to: " + String(describing: peripheral))
        refreshView(secondsUntilRepeat: 0)//force refresh without looping as soon as a new peripheral is connected
       peripheral.discoverServices([heartRateServiceCBUUID])
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        let index = findInDeviceList(peripheral: peripheral)
//        if (index != -1) {
//            blockRefreshes()
//            tableView.beginUpdates()
//            deviceList.remove(at: index)
//            tableView.endUpdates()
//            unblockRefreshes()
//            
//        } else {
//            print("couldnt find device in list")
//        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Service: " + String(describing: service))
            print("Service Characteristics: ")
            peripheral.discoverCharacteristics(nil, for: service)
            
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
            
            if characteristic.properties.contains(.notify) {
                //print("\(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
                
                
            }
            
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        switch characteristic.uuid {
            case heartRateMeasurementCharacteristicCBUUID:
                let bpm = heartRate(from: characteristic)
                let index = findInDeviceList(peripheral: peripheral)
                if (index != -1) {
                    updateHRForDeviceAtIndex(index: index, heartRate: bpm)
                } else {
                    print("couldnt find device in list")
                }
                
                //refreshView()//can remove in favor of timer
            default:
                print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    
    
    private func heartRate(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart Rate Value Format is in the 2nd byte
            return Int(byteArray[1])
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
        }
        /*So regarding the << 8, if the heart rate value is a 16-bit number, it will be present in the 2nd and 3rd bytes. Let’s say the 2nd byte has a value of 1, and the 3rd byte has a value of 5. The value of the 2nd bit has to be multiplied by 256 and then has to be added to the 3rd bit to give you the heart rate, which would be 256 + 5 = 261. Shifting the number by 8 bits to the left is the same as multiplying by 256. https://www.raywenderlich.com/177848/core-bluetooth-tutorial-for-ios-heart-rate-monitor */
    }
} 
