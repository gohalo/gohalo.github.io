#!/bin/bash

set -e
OUTDIR=pki

mkdir -p $OUTDIR/{ca,svr}
mkdir -p $OUTDIR/ca/inter

## 生成根证书，如果不需要密码可以将-passout替换为-nodes
openssl genrsa -aes128 -out $OUTDIR/ca/key.pem -passout 'pass:YourPassHere' 4096
openssl req -x509 -days 3650 -passin 'pass:YourPassHere' -key $OUTDIR/ca/key.pem \
	-subj "/C=CN/O=Cargo/OU=CertCenter/CN=Cargo Trust Root R1" -out $OUTDIR/ca/cert.pem
#openssl rsa -text -noout -passin 'pass:YourPassHere' -in $OUTDIR/ca/key.pem
#openssl x509 -noout -text -in $OUTDIR/ca/cert.pem


# 生成中间证书的私钥文件以及证书请求文件
openssl genrsa -aes128 -out $OUTDIR/ca/inter/key.pem -passout 'pass:YourPassHere' 4096
openssl req -new -passin 'pass:YourPassHere' -key $OUTDIR/ca/inter/key.pem \
	-out $OUTDIR/ca/inter/cert.csr -subj "/C=CN/O=Cargo, Inc./CN=Cargo Trust CA-1"
#openssl rsa -text -noout -passin 'pass:YourPassHere' -in $OUTDIR/ca/inter/key.pem
#openssl req -noout -text -in $OUTDIR/ca/inter/cert.csr
echo 'basicConstraints=critical,CA:TRUE' > $OUTDIR/ca/inter/tls.cnf
openssl x509 -req -days 3650 -CAcreateserial \
	-CA $OUTDIR/ca/cert.pem -CAkey $OUTDIR/ca/key.pem -passin 'pass:YourPassHere' \
	-in $OUTDIR/ca/inter/cert.csr -out $OUTDIR/ca/inter/cert.pem -extfile $OUTDIR/ca/inter/tls.cnf
#openssl x509 -noout -text -in $OUTDIR/ca/inter/cert.pem
openssl verify -CAfile $OUTDIR/ca/cert.pem $OUTDIR/ca/inter/cert.pem


# 生成服务器的CSR文件以及证书文件
openssl genrsa -aes128 -out $OUTDIR/svr/key.pem -passout 'pass:YourPassHere' 4096

cat << EOF > $OUTDIR/svr/tls.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
IP.1 = 127.0.0.1
DNS.1 = *.cargo.com
EOF
openssl req -new -passin 'pass:YourPassHere' -key $OUTDIR/svr/key.pem \
	-config $OUTDIR/svr/tls.cnf -out $OUTDIR/svr/cert.csr \
	-subj "/C=CN/ST=ZheJiang/L=HangZhou/O=Cargo, Inc./CN=*.cargo.com"
openssl x509 -req -passin 'pass:YourPassHere' -CAcreateserial -days 365 \
	-extfile $OUTDIR/svr/tls.cnf -extensions v3_req \
	-CA $OUTDIR/ca/inter/cert.pem -CAkey $OUTDIR/ca/inter/key.pem \
	-in $OUTDIR/svr/cert.csr -out $OUTDIR/svr/cert.pem
# 将根证书和中间证书合并
cat $OUTDIR/ca/cert.pem $OUTDIR/ca/inter/cert.pem > $OUTDIR/ca/cert-all.pem
# 验证生成的证书
openssl verify -CAfile $OUTDIR/ca/cert-all.pem $OUTDIR/svr/cert.pem

