// License-Identifier: MIT
// Unity Deploy Utils
import * as path from "path";
import * as fs from "fs";

/**
 * Create Scriptable Object in Unity project which contains smart contract address and abi
 * @author Rohin Knight
 */
export function updateUnitySmartContract(
  networkName: string,
  contractName: string,
  address: string,
  exportDir: string
) {
  // Read contract json from artifacts folder which will contain the ABI
  const jsonFilepath = path.join(
    __dirname,
    `../artifacts/contracts/${contractName}.sol/${contractName}.json`
  );
  const jsonStr = fs.readFileSync(jsonFilepath);

  // Convert JSON to Object so we can access the ABI object
  const jsonObj = JSON.parse(jsonStr.toString());

  // Convert ABI object back into JSON using stringify so there is no whitespace
  const abi = JSON.stringify(jsonObj.abi);

  // Create export dir if not exist
  if (!fs.existsSync(exportDir)) {
    console.log("Created directory %s", exportDir);
    fs.mkdirSync(exportDir, { recursive: true });
  }

  // Setup export filepath and content
  const exportFilepath = path.join(exportDir, `${contractName}.asset`);
  const yamlFile = `%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!114 &11400000
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: 6f6e50ddbf0ff83408085da6b1d67b92, type: 3}
  m_Name: NFTMinter
  m_EditorClassIdentifier: 
  Address: ${address}
  ABI: '${abi}'
`;

  fs.writeFile(exportFilepath, yamlFile, function (err: any) {
    if (err) {
      return console.log(err);
    }
    console.log(
      `Exported address and abi for ${contractName} to ${exportFilepath}`
    );
  });
}
