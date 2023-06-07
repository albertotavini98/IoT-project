/**
 *  @author Marco Petri and Alberto Tavini
 */

#include "node.h"

configuration nodeAppC {}

implementation {
	/****** COMPONENTS *****/
	components MainC, nodeC as App;
	components new AMSenderC(AM_MY_MSG);
	components new AMReceiverC(AM_MY_MSG);
	components new TimerMilliC();
	components ActiveMessageC;
	//add the other components here

	/****** INTERFACES *****/
	//Boot interface
	App.Boot -> MainC.Boot;

	/****** Wire the other interfaces down here *****/
	//Send and Receive interfaces
	//Radio Control
	//Interfaces to access package fields
	//Timer interface
	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.PacketAcknowledgements -> ActiveMessageC;
	App.MilliTimer -> TimerMilliC;
	App.Packet -> AMSenderC;
}
