locals {
  service_name = "forum"
  owner        = "Community Team"
}

provider "aws" {
  region = "ap-southeast-1"
}


#Create network related resources for functional network
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  
  tags = {
    Name = "public route table"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "db1" {
  subnet_id      = aws_subnet.db1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "db2" {
  subnet_id      = aws_subnet.db2.id
  route_table_id = aws_route_table.public.id
}


resource "aws_subnet" "web" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "Web Subnet"
  }
}

resource "aws_subnet" "db1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "DB Subnet"
  }
}

resource "aws_subnet" "db2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "DB Subnet"
  }
}

#create Security groups for public, web, and db tier
resource "aws_security_group" "publicSG" {
  name        = "publicSG"
  description = "Allow port 80 public traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "http port from public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "publicSG"
  }
}


resource "aws_security_group" "webSG" {
  name        = "webSG"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Http from Load Balancer"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.publicSG.id]
  }
  #for test
  /*
  ingress {
    description = "Http from Load Balancer"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Http from Load Balancer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["x.x.x.x/32"]
  }
  */

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebSG"
  }
}

resource "aws_security_group" "DBSG" {
  name        = "DBSG"
  description = "Allow RDS inbound Traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "RDS port from Web Tier"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.webSG.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DBSG"
  }
}


#create resources
resource "aws_elb" "clb" {
  name               = "Classic-Load-Balancer"
  security_groups = [aws_security_group.publicSG.id]

  internal           = false
  subnets            = [aws_subnet.web.id]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }

  listener {
    lb_port = "80"
    lb_protocol = "http"
    instance_port = "8080"
    instance_protocol = "http"
  }

  tags = {
    Environment = "development"
  }
}


#create rds instance and subnet
resource "aws_db_subnet_group" "dbsubnet" {
  name       = "main"
  subnet_ids = [aws_subnet.db1.id, aws_subnet.db2.id]

  tags = {
    Name = "My DB subnet group"
  }
}


resource "aws_db_instance" "defaultdb" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "foo"
  password             = "foobarbaz"
  db_subnet_group_name = aws_db_subnet_group.dbsubnet.id
  vpc_security_group_ids = [aws_security_group.DBSG.id]
}

#Launch configuration and auto scaling
resource "aws_launch_configuration" "web_conf" {
  name          = "web_config"
  image_id      = "ami-09a6a7e49bd29554b"
  instance_type = "t2.micro"
  user_data = <<EOF
#!/bin/bash
apt update -y
apt install -y golang git mysql-server

#create database on rds, ignore database failure if db already exist
export DATABASE_NAME="gowtdb"
export DATABASE_USERNAME="foo"
export DATABASE_PASSWORD="foobarbaz"
export DATABASE_SERVER="${aws_db_instance.defaultdb.address}"
export DATABASE_PORT="3306"
mysql --host=$DATABASE_SERVER --user=$DATABASE_USERNAME --password=$DATABASE_PASSWORD -e "CREATE DATABASE $DATABASE_NAME CHARACTER SET utf8 COLLATE utf8_unicode_ci;USE $DATABASE_NAME;CREATE TABLE tools (id int(11) NOT NULL AUTO_INCREMENT,name varchar(80) COLLATE utf8_unicode_ci DEFAULT NULL,category varchar(80) COLLATE utf8_unicode_ci DEFAULT NULL,url varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,rating int(11) DEFAULT NULL,notes text COLLATE utf8_unicode_ci,PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;"

#create git repo for script
mkdir /opt/web/
cd /opt/web/
git clone https://github.com/le4ndro/gowt.git

#store rest of script to be executed on startup script
touch  /opt/web/webstart.sh
chmod 755 /opt/web/webstart.sh


echo '#!/bin/bash' >> /opt/web/webstart.sh
echo 'cd /opt/web/gowt' >> /opt/web/webstart.sh
echo 'go get -u github.com/go-sql-driver/mysql' >> /opt/web/webstart.sh
echo 'export DATABASE_NAME="gowtdb"' >> /opt/web/webstart.sh
echo 'export DATABASE_USERNAME="foo"' >> /opt/web/webstart.sh
echo 'export DATABASE_PASSWORD="foobarbaz"' >> /opt/web/webstart.sh
echo 'export DATABASE_SERVER="${aws_db_instance.defaultdb.address}"' >> /opt/web/webstart.sh
echo 'export DATABASE_PORT="3306"' >> /opt/web/webstart.sh
echo '#execute program' >> /opt/web/webstart.sh
echo 'go run main.go' >> /opt/web/webstart.sh

#add script as service
touch /etc/systemd/system/webstart.service
chmod 777 /etc/systemd/system/webstart.service
echo '[Unit]' >> /etc/systemd/system/webstart.service
echo 'Description=Run service as user deepak' >> /etc/systemd/system/webstart.service
echo 'DefaultDependencies=no' >> /etc/systemd/system/webstart.service
echo 'After=network.target' >> /etc/systemd/system/webstart.service
echo '' >> /etc/systemd/system/webstart.service
echo '[Service]' >> /etc/systemd/system/webstart.service
echo 'Type=simple' >> /etc/systemd/system/webstart.service
echo 'User=ubuntu' >> /etc/systemd/system/webstart.service
echo 'Group=admin' >> /etc/systemd/system/webstart.service
echo 'ExecStart=/opt/web/webstart.sh' >> /etc/systemd/system/webstart.service
echo 'TimeoutStartSec=0' >> /etc/systemd/system/webstart.service
echo 'RemainAfterExit=yes' >> /etc/systemd/system/webstart.service
echo '' >> /etc/systemd/system/webstart.service
echo '[Install]' >> /etc/systemd/system/webstart.service
echo 'WantedBy=default.target' >> /etc/systemd/system/webstart.service
~                              

#excute service for the first time
systemctl daemon-reload
systemctl enable webstart.service
service webstart start

	EOF
  security_groups = [ aws_security_group.webSG.id ] 
  associate_public_ip_address = true
  key_name = "testkey"
  lifecycle {
    create_before_destroy = true
  }
}

resource "time_sleep" "db_warmup" {
  depends_on = [aws_db_instance.defaultdb]
  create_duration = "5m"
}

resource "aws_autoscaling_group" "webset" {
  depends_on = [time_sleep.db_warmup]
  name                      = "webset"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 3600
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  load_balancers = [aws_elb.clb.id]
  launch_configuration      = aws_launch_configuration.web_conf.name
  vpc_zone_identifier       = [aws_subnet.web.id]

  timeouts {
    delete = "15m"
  }

}

output "elb_dns_name" {
  value = aws_elb.clb.dns_name
}