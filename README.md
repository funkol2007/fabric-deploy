自动部署如下结构：
=
| IP       | 节点         | 域名|
|:-----------:| :-------------:| :-------------:|
| 10.254.186.164|orderer  |  orderer.gyl.com|
| 10.254.186.164 | peer |peer0.org1.example.com  |
| 10.254.247.165 | peer |peer1.org1.example.com   |
| 10.254.207.154 | peer  |peer0.org2.example.com  |

前置环境：
=
* go v1.9+
* fabric v1.1的bin文件已经放到$PATH
* 写好的chaincode

启动环境：
* sh deploy.sh mychannelID

清空环境：
* sh clear.sh
