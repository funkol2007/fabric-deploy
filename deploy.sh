path=`pwd`
mychannel=$1

if [ $# -ne 1 ]; then
        echo "请添加channelID"
        echo $mychannel
	exit
else
        echo "start deploying"
fi

#创建文件夹
if [ ! -d ~/peer  ];then
  mkdir ~/peer
else
  echo dir exist
fi

if [ ! -d ~/orderer  ];then
  mkdir ~/orderer
else
  echo dir exist
fi

echo "##########################################################"
echo "##### Generate certificates using cryptogen tool #########"
echo "##########################################################"

cryptogen generate --config=crypto-config.yaml --output ./certs
mkdir orderer.example.com
cp -rf certs/ordererOrganizations/example.com/orderers/orderer.example.com/* orderer.example.com/
cp orderer.yaml orderer.example.com
cp orderer_start.sh orderer.example.com/start.sh
mkdir orderer.example.com/data

mkdir peer0.org1.example.com
cp -rf certs/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/* peer0.org1.example.com/
cp core.yaml peer0.org1.example.com
mkdir peer0.org1.example.com/data
cp -rf peer0.org1.example.com/ peer1.org1.example.com/
rm -rf peer1.org1.example.com/msp/
rm -rf peer1.org1.example.com/tls/
cp -rf certs/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/* peer1.org1.example.com/
sed -i "s/peer0.org1.example.com/peer1.org1.example.com/g" peer1.org1.example.com/core.yaml
cp -rf peer0.org1.example.com/ peer0.org2.example.com/
rm -rf peer0.org2.example.com/msp/
rm -rf peer0.org2.example.com/tls/
cp -rf certs/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/*  peer0.org2.example.com/
sed -i "s/peer0.org1.example.com/peer0.org2.example.com/g" peer0.org2.example.com/core.yaml
sed -i "s/Org1MSP/Org2MSP/g" peer0.org2.example.com/core.yaml

#传输peer/orderer
cp peer_start.sh peer0.org1.example.com/start.sh
cp peer_start.sh peer1.org1.example.com/start.sh
cp peer_start.sh peer0.org2.example.com/start.sh

echo "##########################################################"
echo "#########  Generating Orderer Genesis block ##############"
echo "##########################################################"
 
#生成创世区块
configtxgen -profile TwoOrgsOrdererGenesis -outputBlock ./genesisblock
cp genesisblock ~/orderer

#远程部署peer
cd $path
ssh dc2-user@10.254.247.165 "mkdir -p ~/peer; rm -rf ~/peer/*"
ssh dc2-user@10.254.207.154 "mkdir -p  ~/peer; rm -rf ~/peer/*"
scp -r orderer.example.com/* ~/orderer/
scp -r peer0.org1.example.com/* ~/peer/
scp -r peer1.org1.example.com/* 10.254.247.165:~/peer/
scp -r peer0.org2.example.com/* 10.254.207.154:~/peer/

echo "##########################################################"
echo "############  start orderer && peers  ####################"
echo "##########################################################"
#启动本地的peer/orderer
cd ~/orderer
echo "strating orderer ..."
sh start.sh
if [ $? != 0 ]; then
    echo "orderer start  fail"
	exit 1
else
	echo "orderer start success"
fi

cd ~/peer
echo "starting peer ..."
sh start.sh
if [ $? != 0 ]; then
    echo "peer start  fail"
        exit 1
else
        echo "peer start success"
fi

#启动远程peer
ssh dc2-user@10.254.247.165 "cd ~/peer; sh start.sh > /dev/null 2>&1 &"
ssh dc2-user@10.254.207.154 "cd ~/peer; sh start.sh > /dev/null 2>&1 &"

echo "##########################################################"
echo "#########  Create Adimn && Users in each ORG #############"
echo "##########################################################"
#创建用户
#org1 Admin(peer0)
cd $path
mkdir Admin_1
cp -rf certs/peerOrganizations/org1.example.com/users/Admin@org1.example.com/* Admin_1/
cp peer0.org1.example.com/core.yaml  Admin_1/
cp peer.sh Admin_1/

cd Admin_1
echo `./peer.sh node status`

#org1 user1 (peer1)
cd $path
cp -rf  Admin_1/ User_1/
rm -rf  User_1/msp
rm -rf  User_1/tls
cp -rf  certs/peerOrganizations/org1.example.com/users/User1@org1.example.com/* User_1/
sed -i "s/peer0.org1.example/peer1.org1.example/g" User_1/peer.sh

#org2 Admin
cp -rf  Admin_1/ Admin_2/
rm -rf  Admin_2/msp/
rm -rf  Admin_2/tls/
cp -rf certs/peerOrganizations/org2.example.com/users/Admin@org2.example.com/* Admin_2/
sed -i "s/peer0.org1.example/peer0.org2.example/g" Admin_2/peer.sh
sed -i "s/Org1MSP/Org2MSP/g" Admin_2/peer.sh
sed -i "s/peer0.org1.example.com/peer0\.org2\.example.com/g" Admin_2/core.yaml
sed -i "s/Org1MSP/Org2MSP/g" Admin_2/core.yaml

#复制根证书
#把使用org1的另一个身份控制peer1.org1.example.com
cp -rf Admin_1/ Admin_1_2/
sed -i "s/peer0.org1.example/peer1.org1.example/g" Admin_1_2/peer.sh
cp certs/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem  Admin_1/
cp certs/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem  User_1/
cp certs/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem  Admin_2/
cp certs/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem  Admin_1_2/

echo "##########################################################"
echo "#########  Create Channel && Anchor Peer #################"
echo "##########################################################"
#创建channel
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx $mychannel.tx -channelID $mychannel
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate Org1MSPanchors.tx -channelID $mychannel -asOrg Org1MSP
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate Org2MSPanchors.tx -channelID $mychannel -asOrg Org2MSP

cd  Admin_1
./peer.sh channel create -o orderer.example.com:7050 -c $mychannel -f ../$mychannel.tx --tls true --cafile tlsca.example.com-cert.pem
cp $mychannel.block ../Admin_2
cp $mychannel.block ../User_1
cp $mychannel.block ../Admin_1_2


#peer加入channel
./peer.sh channel join -b $mychannel.block

if [ $? != 0 ]; then
    echo "peer0.org1.example join $mychannel fail"
        exit 1
else
        echo "------peer0.org1.example join $mychannel success !!!"
fi

cd ../Admin_1_2/
./peer.sh channel join -b $mychannel.block
if [ $? != 0 ]; then
    echo "peer1.org1.example join $mychannel fail"
        exit 1
else
        echo "------peer1.org1.example join $mychannel success !!!"
fi

cd ../Admin_2/
./peer.sh channel join -b $mychannel.block
if [ $? != 0 ]; then
    echo "peer0.org2.example join $mychannel fail"
        exit 1
else
        echo "------peer0.org2.example join $mychannel success !!!"
fi

cd ../Admin_1/
./peer.sh channel update -o orderer.example.com:7050 -c $mychannel -f ../Org1MSPanchors.tx --tls true --cafile ./tlsca.example.com-cert.pem

cd ../Admin_2/
./peer.sh channel update -o orderer.example.com:7050 -c $mychannel -f ../Org2MSPanchors.tx --tls true --cafile ./tlsca.example.com-cert.pem

echo "##########################################################"
echo "#################### ChainCode install ###################"
echo "##########################################################"
#安装合约
go get github.com/introclass/hyperledger-fabric-chaincodes/demo
cd $path
cd Admin_1
./peer.sh chaincode package demo-pack.out -n demo -v 0.0.1 -s -S -p github.com/introclass/hyperledger-fabric-chaincodes/demo
./peer.sh chaincode signpackage demo-pack.out signed-demo-pack.out
cp signed-demo-pack.out ../Admin_1_2/
cp signed-demo-pack.out ../Admin_2/
./peer.sh chaincode install ./signed-demo-pack.out

if [ $? != 0 ]; then
    echo "peer0.org1.example.com install $mychannel fail"
        exit 1
else
        echo "------peer0.org1.example.com $mychannel success !!!"
fi


cd ../Admin_1_2
./peer.sh chaincode install ./signed-demo-pack.out
if [ $? != 0 ]; then
    echo "peer1.org1.example.com install $mychannel fail"
        exit 1
else
        echo "------peer1.org1.example.com $mychannel success !!!"
fi

cd ../Admin_2
./peer.sh chaincode install ./signed-demo-pack.out
if [ $? != 0 ]; then
    echo "peer0.org2.example.com install $mychannel fail"
        exit 1
else
        echo "------peer0.org2.example.com $mychannel success !!!"
fi





echo "##########################################################"
echo "#################### ChainCode invoke  ###################"
echo "##########################################################"
cd ../Admin_1
echo "Admin_1 instantiate"
./peer.sh chaincode instantiate -o orderer.example.com:7050 --tls true --cafile ./tlsca.example.com-cert.pem -C $mychannel -n demo -v 0.0.1 -c '{"Args":["init"]}' -P "OR('Org1MSP.member','Org2MSP.member')"
sleep 10
echo "Admin_1 invoke"
./peer.sh chaincode invoke -o orderer.example.com:7050  --tls true --cafile ./tlsca.example.com-cert.pem -C $mychannel -n demo -c '{"Args":["write","key1","key1valueisabc"]}'
sleep 2
cd ../Admin_2
echo "Admin_2 query"
./peer.sh chaincode query -C $mychannel -n demo -c '{"Args":["query","key1"]}'
sleep 2
cd ../User_1
echo "User_1 query"
./peer.sh chaincode query -C $mychannel -n demo -c '{"Args":["query","key1"]}'



echo "deploy finished !!!"
