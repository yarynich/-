#!/bin/bash
#Connect to SQL1
ssh root@sql1.ypa.local << ED
service postgresql restart
#################################################
#   CREATE 				DATABASE		        #
#################################################
psql -U postgres -c "CREATE DATABASE test;"
psql   -d test  -c "CREATE TABLE test (name varchar(50), surname varchar(50));"
psql -U postgres -d test  -c "INSERT INTO test (name, surname) VALUES ('Evgeny', 'Yarynich');"
psql -U postgres -d test  -c "INSERT INTO test (name, surname) VALUES ('Pham','Thien');"
psql -U postgres -d test  -c "INSERT INTO test (name, surname) VALUES ('Anna', 'Nikolaeva');"

#Create user replica
psql -U postgres -c "CREATE USER replica REPLICATION LOGIN CONNECTION LIMIT 2 ENCRYPTED PASSWORD 'qWe12345';"
cp /etc/postgresql/10/main/pg_hba.conf /etc/postgresql/10/main/pg_hba{`date +%s`}.bkp
sed  -i '/host    replication/d' /etc/postgresql/10/main/pg_hba.conf
echo "host    replication     replica             192.168.1.0/24                 trust" | tee -a /etc/postgresql/10/main/pg_hba.conf

cp /etc/postgresql/10/main/postgresql.conf /etc/postgresql/10/main/postgresql{`date +%s`}.bkp

if grep -Fxq "listen_addresses = '*'" /etc/postgresql/10/main/postgresql.conf
    then echo "exist"
else
    echo "listen_addresses = '*'" | tee -a /etc/postgresql/10/main/postgresql.conf
fi
if grep -Fxq "hot_standby = on" /etc/postgresql/10/main/postgresql.conf
    then echo "exist"
else
    echo "hot_standby = on" | tee -a /etc/postgresql/10/main/postgresql.conf
fi
if grep -Fxq "wal_level = replica" /etc/postgresql/10/main/postgresql.conf
    then echo "exist"
else
    echo "wal_level = replica" | tee -a /etc/postgresql/10/main/postgresql.conf
fi
if grep -Fxq "max_wal_senders = 10" /etc/postgresql/10/main/postgresql.conf
    then echo "exist"
else
    echo "max_wal_senders = 10" | tee -a /etc/postgresql/10/main/postgresql.conf
fi
if grep -Fxq "wal_keep_segments = 32" /etc/postgresql/10/main/postgresql.conf
    then echo "exist"
else
    echo "wal_keep_segments = 32" | tee -a /etc/postgresql/10/main/postgresql.conf
fi
service postgresql restart

ED
echo "Installed"



#Connect to SQL2
ssh root@sql2.ypa.local << ED
service postgresql start

#make student
mkdir /home/script
cat > /home/script/student.sh << STA
#!/bin/bash
while :
do
if pg_isready -h sql1.ypa.local; then
  echo "fine"
elif test -f /tmp/test1_approve; then
  touch /tmp/test1
else echo "error"
fi;
sleep 1
done
STA

touch /etc/systemd/system/student.service
cat > /etc/systemd/system/student.service << STA
[Unit]
Description = Student on sql2.ypa.local
[Service]
RemainAfterExit=true
ExecStart=/bin/sh /home/script/student.sh
Type=simple
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
STA

chmod +x /etc/systemd/system/student.service

systemctl enable student
systemctl restart student


ED
echo "Installed"



#make student service
mkdir /home/script
cat > /home/script/student.sh << STA
#!/bin/bash
while :
do
if pg_isready -h sql1.ypa.local; then
  echo "fine"
  ssh root@sql1.ypa.local "rm /tmp/test1_approve"
  ssh root@sql2.ypa.local "iptables -D OUTPUT -d 192.168.1.10 -j DROP"
else
  ssh root@sql2.ypa.local "touch /tmp/test1_approve"
  ssh root@sql2.ypa.local "iptables -A OUTPUT -d 192.168.1.10 -j DROP"
fi;
sleep 5
done
STA


touch /etc/systemd/system/student.service
cat > /etc/systemd/system/student.service << STA
[Unit]
Description = Student on student.ypa.local
[Service]
RemainAfterExit=true
ExecStart=/bin/sh /home/script/student.sh
Type=simple
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
STA

chmod +x /etc/systemd/system/student.service

systemctl enable student
systemctl restart student
