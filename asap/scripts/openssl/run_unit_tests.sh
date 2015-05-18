#!/bin/sh

echo "### Starting tests at $(date -Ins)"

for i in $(seq 1 1); do
    sh <<EOF
../util/shlib_wrap.sh ./destest
../util/shlib_wrap.sh ./ideatest
../util/shlib_wrap.sh ./shatest
../util/shlib_wrap.sh ./sha1test
../util/shlib_wrap.sh ./sha256t
../util/shlib_wrap.sh ./sha512t
../util/shlib_wrap.sh ./md4test
../util/shlib_wrap.sh ./md5test
../util/shlib_wrap.sh ./hmactest
../util/shlib_wrap.sh ./md2test
../util/shlib_wrap.sh ./mdc2test
../util/shlib_wrap.sh ./wp_test
../util/shlib_wrap.sh ./rmdtest
../util/shlib_wrap.sh ./rc2test
../util/shlib_wrap.sh ./rc4test
../util/shlib_wrap.sh ./rc5test
../util/shlib_wrap.sh ./bftest
../util/shlib_wrap.sh ./casttest
../util/shlib_wrap.sh ./randtest
echo starting big number library test, could take a while...
../util/shlib_wrap.sh ./bntest >tmp.bntest
echo quit >>tmp.bntest
echo "running bc"
<tmp.bntest sh -c "`sh ./bctest ignore`" | perl -e '$i=0; while (<STDIN>) {if (/^test (.*)/) {print STDERR "\nverify $1";} elsif (!/^0$/) {die "\nFailed! bc: $_";} else {print STDERR "."; $i++;}} print STDERR "\n$i tests passed\n"'
echo 'test a^b%c implementations'
../util/shlib_wrap.sh ./exptest
echo 'test elliptic curves'
../util/shlib_wrap.sh ./ectest
echo 'test ecdsa'
../util/shlib_wrap.sh ./ecdsatest
echo 'test ecdh'
../util/shlib_wrap.sh ./ecdhtest
sh ./testenc
echo test normal x509v1 certificate
sh ./tx509 2>/dev/null
echo test first x509v3 certificate
sh ./tx509 v3-cert1.pem 2>/dev/null
echo test second x509v3 certificate
sh ./tx509 v3-cert2.pem 2>/dev/null
sh ./trsa 2>/dev/null
../util/shlib_wrap.sh ./rsa_test
sh ./tcrl 2>/dev/null
sh ./tsid 2>/dev/null
echo "Generate and verify a certificate request"
sh ./testgen
echo "Generate and verify a certificate request"
sh ./testgen
sh ./treq 2>/dev/null
sh ./treq testreq2.pem 2>/dev/null
sh ./tpkcs7 2>/dev/null
sh ./tpkcs7d 2>/dev/null
echo "The following command should have some OK's and some failures"
echo "There are definitly a few expired certificates"
../util/shlib_wrap.sh ../apps/openssl verify -CApath ../certs/demo ../certs/demo/*.pem
echo "Generate a set of DH parameters"
../util/shlib_wrap.sh ./dhtest
echo "Generate a set of DSA parameters"
../util/shlib_wrap.sh ./dsatest
../util/shlib_wrap.sh ./dsatest -app2_1
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
if ../util/shlib_wrap.sh ../apps/openssl no-rsa; then \
	  echo "skipping CA.sh test -- requires RSA"; \
	else \
	  echo "Generate and certify a test certificate via the 'ca' program"; \
	  sh ./testca; \
	fi
echo "Manipulate the ENGINE structures"
../util/shlib_wrap.sh ./enginetest
../util/shlib_wrap.sh ./evp_test evptests.txt
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "Generate and certify a test certificate"
sh ./testss
cat certCA.ss certU.ss > intP1.ss
cat certCA.ss certU.ss certP1.ss > intP2.ss
echo "test SSL protocol"
../util/shlib_wrap.sh ./ssltest -test_cipherlist
sh ./testssl keyU.ss certU.ss certCA.ss
sh ./testsslproxy keyP1.ss certP1.ss intP1.ss
sh ./testsslproxy keyP2.ss certP2.ss intP2.ss
if ../util/shlib_wrap.sh ../apps/openssl no-rsa; then \
	  echo "skipping testtsa test -- requires RSA"; \
	else \
	  sh ./testtsa; \
	fi
echo "Test IGE mode"
../util/shlib_wrap.sh ./igetest
echo "Test JPAKE"
../util/shlib_wrap.sh ./jpaketest
echo "Test SRP"
../util/shlib_wrap.sh ./srptest
echo "CMS consistency test"
perl cms-test.pl
echo "Test X509v3_check_*"
../util/shlib_wrap.sh ./v3nametest
echo "Test OCSP"
sh ./tocsp
../util/shlib_wrap.sh ./gost2814789t
EOF
done

echo "### Ending tests at $(date -Ins)"
