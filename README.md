This is a simple TSO command processor, written in assembler, to manipulate the JES symbols of the TSO session. It uses:

* the [JES Symbol Service](https://www.ibm.com/support/knowledgecenter/SSLTBW_2.2.0/com.ibm.zos.v2r2.hasc300/iazsymbl.htm)
* [IKJPARS](https://www.ibm.com/support/knowledgecenter/en/SSLTBW_2.3.0/com.ibm.zos.v2r3.ikjb600/ikj2k200_Using_the_.htm), the TSO command line argument parser
* [IKJEFT02](https://www.ibm.com/support/knowledgecenter/en/SSLTBW_2.3.0/com.ibm.zos.v2r3.ikjb600/ikj2k200_Using_the_TSO_E_Message_Issuer_Routine__IKJEFF02_.htm), the TSO message issuer routine

It currently has absolutely wretched error handling.


