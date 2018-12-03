killall -9 orderer
killall -9 peer
rm -rf ~/peer	
rm -rf ~/orderer
rm -rf Admin\@org1.example.com/
rm -rf certs/
rm -rf genesisblock
rm -rf orderer.example.com/
rm -rf peer0.org*
rm -rf peer1.org1.example.com/
rm -rf Admin_1
rm -rf Admin_2
rm -rf User_1
rm -rf Admin_1_2
rm -rf *.tx
ssh dc2-user@10.254.247.165 "killall -9 peer;rm -rf ~/peer/*"
ssh dc2-user@10.254.207.154 "killall -9 peer;rm -rf ~/peer/*"
