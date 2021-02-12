Since region us-east-2 has 3 zones it makes sense to create at least 3 subnets within the VPC.

Address:   192.168.0.0           11000000.10101000.000000 00.00000000
Netmask:   255.255.252.0 = 22    11111111.11111111.111111 00.00000000
Wildcard:  0.0.3.255             00000000.00000000.000000 11.11111111
=>
Network:   192.168.0.0/22        11000000.10101000.000000 00.00000000 (Class C)
Broadcast: 192.168.3.255         11000000.10101000.000000 11.11111111
HostMin:   192.168.0.1           11000000.10101000.000000 00.00000001
HostMax:   192.168.3.254         11000000.10101000.000000 11.11111110
Hosts/Net: 1022                  (Private Internet)


Subnets

Netmask:   255.255.255.0 = 24    11111111.11111111.11111111 .00000000
Wildcard:  0.0.0.255             00000000.00000000.00000000 .11111111

Network:   192.168.0.0/24        11000000.10101000.00000000 .00000000 (Class C)
Broadcast: 192.168.0.255         11000000.10101000.00000000 .11111111
HostMin:   192.168.0.1           11000000.10101000.00000000 .00000001
HostMax:   192.168.0.254         11000000.10101000.00000000 .11111110
Hosts/Net: 254                   (Private Internet)


Network:   192.168.1.0/24        11000000.10101000.00000001 .00000000 (Class C)
Broadcast: 192.168.1.255         11000000.10101000.00000001 .11111111
HostMin:   192.168.1.1           11000000.10101000.00000001 .00000001
HostMax:   192.168.1.254         11000000.10101000.00000001 .11111110
Hosts/Net: 254                   (Private Internet)


Network:   192.168.2.0/24        11000000.10101000.00000010 .00000000 (Class C)
Broadcast: 192.168.2.255         11000000.10101000.00000010 .11111111
HostMin:   192.168.2.1           11000000.10101000.00000010 .00000001
HostMax:   192.168.2.254         11000000.10101000.00000010 .11111110
Hosts/Net: 254                   (Private Internet)


Network:   192.168.3.0/24        11000000.10101000.00000011 .00000000 (Class C)
Broadcast: 192.168.3.255         11000000.10101000.00000011 .11111111
HostMin:   192.168.3.1           11000000.10101000.00000011 .00000001
HostMax:   192.168.3.254         11000000.10101000.00000011 .11111110
Hosts/Net: 254                   (Private Internet)



Subnets:   4 
Hosts:     1016



In order to create the AMI using Packer you need to create:
- VPC: 192.168.0.0/22.
- Subnet: Any of the 3 subnets is fine.
- Security group: Type=All traffic, Source=MyIP
- Internet GW, and attach it to your VPC. 
- Import your SSH Pub Key to AWS. 
- Add a route for 0.0.0.0/0 to your IGW.
- Subnet Associations: Associate the 3 subnets with your main route table.

Reference: https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html

So you can create those manually if they don't exists already and then from terraform refer to them using datasources. 

Run:
- packer validate jenkins-ami.json
- packer build jenkins-ami.json


TO-DOs: 
- Create Packer VPC with terraform. 
- Execute terraform and packer from a shell script. 
- Move Jenkins terraform files to a sub-directory.

