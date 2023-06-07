/**
 *  @author Marco Petri and Alberto Tavini
 */

#include "node.h"
#include "Timer.h"
#include "unistd.h"
#include "math.h"
#include "stdlib.h"

#define N 5
#define MAX 400

module nodeC {
	uses {
		/****** INTERFACES *****/
		interface Boot;
		interface Receive;
		interface AMSend;
		interface PacketAcknowledgements;
		interface SplitControl as AMControl;
		interface Timer<TMilli> as MilliTimer;
		interface Packet;

		//interfaces for communication
		//interface for timer
		//other interfaces, if needed
		//interface used to perform sensor reading (to get the value from a sensor)
	}
} implementation {

	//a boolean to set the two different ways to operate the system, one with only RTS (hidden node sensible) and one with both RTS and CTS (more resistant)
	bool only_RTS_mode = FALSE;

	// poisson lambda parameter, for each second
	uint32_t poisson_rate = 20;
	uint32_t num_of_failures=0;
	// paragraph 4: value seconds X
	float sleep_time = 0.2;
	//timer iteration value, in milliseconds
	uint32_t timer_duration = 50;
	//a boolean needed for RTS only mode
	bool RTS_SENT= FALSE;
	//a boolean to set to true when a node has sent an RTS and is waiting for an authorization to send
	bool node_is_waiting = FALSE;
	//the counter for the node to use as payload, not sure we need to use a different one for each node?
	uint16_t node_counter = 1;
	uint16_t base_counter = 6; //it starts from number of nodes
	//the arrays where we store for each node: the last counter received, the amount of packets and the PER 
	uint16_t last_received[N];
	uint16_t missed_packets[N];
	float percentage_PER[N];
	
	//variable needed by the event methods
	message_t packet;

	//all the methods we implemented 
	void sendRTS();
	void sendCTS(uint16_t sender);
	void computePER (uint16_t counter, uint16_t sender );
	void sendpayload();
	void initialize_arrays();
	void receiveRTSonly(void* payload);
	void receiveRTSCTS(void* payload);
	void printfinalstats();
	bool allowedtotransmit();

	//***************** START STATION AND TERMINALS ********************//
	//***************** Boot interface ********************//
	event void Boot.booted() {
		dbg_clear("role", "\n");
		dbg("BOOT","[%s]: Each debug line will have [x] on the left identifying the time at which the debug print has been performed.\n", sim_time_string());
		dbg("BOOT","[%s]: Application booted.\n", sim_time_string());
		call AMControl.start();
	}
	
	event void AMControl.startDone(error_t err){
		if (err == SUCCESS) {
			// If the component is the first to be declated, it is the base station, otherwise is a node with a timer to send messages
			if (TOS_NODE_ID > 1) {
				call MilliTimer.startPeriodic(timer_duration);
				dbg("STARTDONE","[%s]: Simple terminal is active on TOS id %d. \n", sim_time_string(), TOS_NODE_ID);
			} else {
				dbg("STARTDONE","[%s]: Base station is active on TOS id %d. \n", sim_time_string(), TOS_NODE_ID);
				initialize_arrays();
			}
		} else {
			dbgerror("STARTDONE", "[%s]: Radio failed to start on TOS id %d. \n", sim_time_string(), TOS_NODE_ID);
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err){
		//here just some messages to alert that a station has halted
		if (TOS_NODE_ID == 1) {
			dbg("STOPDONE", "[%s]: Base station with TOS id %d has stopped. \n", sim_time_string(), TOS_NODE_ID);
		} else {
			dbg("STOPDONE", "[%s]: Simple terminal with TOS id %d has stopped. \n", sim_time_string(), TOS_NODE_ID);
		}
	}
	
	
	//***************** MilliTimer interface ********************//
	event void MilliTimer.fired() {
		// TODO: mettere una variabile status se possiamo trasmettere o no, e nel caso non fare un **** di niente
		//DONE BY ALBE VEN 08/07
		dbg_clear("role", "\n");
		
		//HERE PART ON POISSON RANDOMIZATION
		if (!node_is_waiting) {
			dbg("TIMER", "[%s]: Terminal %d's timer has been fired\n", sim_time_string(), TOS_NODE_ID);
			
			if (allowedtotransmit()) {sendRTS();}
			
		} else {
			dbg("TIMER", "[%s]: Terminal %d's time has fired but it is waiting \n", sim_time_string(), TOS_NODE_ID);
		}
		
	}
	
	bool allowedtotransmit() {
		//this function is called when the timer fires to check against a probability extraction regulated by a poisson distribution 
		//with parameter lambda equal to 20 packets a second (one packet per timer_duration, which is equal to 50 milliseconds) 
		int total_cycles;
		double lambda;
		double e = 2.72;
		double probability;
		double extraction;
		
		total_cycles = 1 + num_of_failures;
		lambda = (double) (poisson_rate * total_cycles *(timer_duration /1000.0));
		probability = 1.0 - pow(e, -lambda);
		extraction = (double) rand() / (double) RAND_MAX;
		
		
		if (extraction <= probability) {
			num_of_failures = 0;
			dbg("PROBABILITY", "[%s]: Node %d has probability %f and sampled value %f SO IT SENDS\n\n\n", sim_time_string(), TOS_NODE_ID, probability, extraction);
			return TRUE;
		}else {
			dbg("PROBABILITY", "[%s]: Node %d has probability %f and sampled value %f SO IT DOESN'T SEND\n", sim_time_string(), TOS_NODE_ID, probability, extraction);
			num_of_failures++;
			return FALSE;
		}
	}

	//***************** Send request function ********************//
	void sendRTS() {
			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			
			//this method will simply be used to send the RTS, the actual message will be sent upon receival of CTS from base
			if (msg != NULL) {
				msg->type = RTS;
				msg->RTS_sender = TOS_NODE_ID;

				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
					dbg("REQUEST", "[%s]: Node %d has broadcasted an RTS \n", sim_time_string(),TOS_NODE_ID);
					
					//this is needed for RTSONLY mode to work correctly
					RTS_SENT=TRUE;
				} else {
					dbgerror("REQUEST", "[%s]: The AMSend didn't work on node %d  \n", sim_time_string(), TOS_NODE_ID);
				}
					
					
					
				
			} else {
				dbgerror("REQUEST", "[%s]: It wasn't possible to create the payload on node %d \n", sim_time_string(),TOS_NODE_ID );
			}
		
	}

	//****************** Task send response *****************//
	void sendCTS(uint16_t sender) {
		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		if (msg != NULL) {
			msg->type = CTS;
			msg->CTS_authorized = sender;
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
					dbg("CLEAR", "[%s]: The base has sent a CTS to %d \n", sim_time_string(),sender );
					
					} else {
						dbgerror("CLEAR", "[%s]: The base has failed to send a CTS to %d \n", sim_time_string(), sender);
					}
					
		}else {
			dbgerror("CLEAR", "[%s]: It wasn't possible to create the payload of the CTS\n", sim_time_string());
		}
	}

	


	//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf, error_t err) {
		
		//this method is only needed in RTS only because only in this case we need to know this way that RTS transmission was completed
		if(only_RTS_mode && RTS_SENT) {
			dbg("SENDDONE", "[%s]: Node %d has sent RTS and now sends payload\n", sim_time_string(), TOS_NODE_ID);
			sendpayload();
			RTS_SENT = FALSE;
		}
		
	}
	
	//this method is called to test the resistance of the traffic to the hidden node problem when there is only RTS
	void receiveRTSonly(void* payload){
	
		my_msg_t* msg = (my_msg_t*)payload;
 	
 		if (msg->type == RTS) {
			
			//if it is the base who received RTS and it is not waiting traffic from another node, it replies with a CTS 
	 		if (TOS_NODE_ID == 1) {
				dbg("RECEIVERTS", "[%s]: The base station has received a RTS and stays IDLE \n", sim_time_string(), TOS_NODE_ID);
				
			} else {
				//if a node receives an RTS it knows it needs to wait before requesting transmission to base 
				dbg("RECEIVERTS", "[%s]: Node %d has seen the RTS from %d and goes to sleep  \n", sim_time_string(), TOS_NODE_ID, msg->RTS_sender);
				
				if (!node_is_waiting) {
					node_is_waiting = TRUE;
					//qui mettiamo una sleep per X secondi e poi reimpostiamo a false? 
					sleep(sleep_time);
					node_is_waiting = FALSE;
				}
			
			}
 
		} else if (msg->type == CNT){
			//station can become listening again
			//only the base should receive this messages because they are not broadcasted so no need to check TOS ID
			dbg("RECEIVERTS", "[%s]: The base station has received packet number %d from node %d \n", sim_time_string(), msg->counter, msg->RTS_sender);
			//function to be defined
			computePER(msg->counter, msg->RTS_sender);
		} else {
			dbg("RECEIVERTS", "[%s]: TYPE ERROR!!!", sim_time_string(), msg->counter, msg->RTS_sender);
		}
	
	}
	
	//this method is called at the receival of a message if we're using the protocol in its entirety
	void receiveRTSCTS(void* payload){
	
		my_msg_t* msg = (my_msg_t*)payload;
		
 	
 		if (msg->type == RTS) {
			
			//if it is the base who received RTS and it is not waiting traffic from another node, it replies with a CTS 
	 		if (TOS_NODE_ID == 1) {
				dbg("RECEIVEBOTH", "[%s]: The base station has received an RTS and is replying with a CTS \n", sim_time_string(), TOS_NODE_ID);

				
				sendCTS(msg->RTS_sender);
			} else {
				//if a node receives an RTS it knows it needs to wait before requesting transmission to base 
				dbg("RECEIVEBOTH", "[%s]: Node %d has seen the RTS from %d and goes to sleep  \n", sim_time_string(), TOS_NODE_ID, msg->RTS_sender);
				
				if (!node_is_waiting) {
					node_is_waiting = TRUE;
					//qui mettiamo una sleep per X secondi e poi reimpostiamo a false? 
					sleep(0.2);
					node_is_waiting = FALSE;
				}
			}

 			
 		} else if (msg->type == CTS) {
			//qui non credo serva un controllo che TOS ID sia maggiore di 1 tanto solo la base manda CTS
			if (msg->CTS_authorized == TOS_NODE_ID) {
				dbg("RECEIVEBOTH", "[%s]: Node %d has received clearance to transmit\n", sim_time_string(), TOS_NODE_ID);
				//function to be defined
				sendpayload();
			} else {
				dbg("RECEIVEBOTH", "[%s]: Node %d has seen the CTS and goes to sleep \n", sim_time_string(), TOS_NODE_ID);
				
				if (!node_is_waiting) {
					node_is_waiting = TRUE;
					//qui mettiamo una sleep per X secondi e poi reimpostiamo a false? 
					sleep(0.2);
					node_is_waiting = FALSE;
				}
				
			}
			
		} else if (msg->type == CNT){
			//station can become listening again
			//only the base should receive this messages because they are not broadcasted so no need to check TOS ID
			dbg("RECEIVEBOTH", "[%s]: The base station has received packet number %d from node %d \n", sim_time_string(), msg->counter, msg->RTS_sender);
			//function to be defined
			computePER(msg->counter, msg->RTS_sender);
		}
		
	}

	//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
	
	 	//here we just call the needed method depending on the implementation we are using
		
		if (!only_RTS_mode) {
			dbg("RECEIVE", "[%s]: Node %d has received a message in RTS/CTS mode \n", sim_time_string(), TOS_NODE_ID);
			receiveRTSCTS(payload);
			
		}else {
			dbg("RECEIVE", "[%s]: Node %d has received a message in RTS ONLY mode\n", sim_time_string(), TOS_NODE_ID);
			receiveRTSonly(payload);
		}

 		return buf;
	}
	
	void sendpayload() {
		//this is the function to senD the actual message with the counter value
		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		
		if (msg != NULL) {
			msg->type = CNT;
			msg->counter = node_counter;
			
			node_counter++;
			
			if (call AMSend.send(1, &packet, sizeof(my_msg_t)) == SUCCESS) {
					dbg("COUNTER", "[%s]: Node %d has sent CNT message with counter %d !!!!!!!!!!\n", sim_time_string(),TOS_NODE_ID, msg->counter);
					
					} else {
						dbgerror("COUNTER", "[%s]: The CNT send didn't work on node %d  \n", sim_time_string(), TOS_NODE_ID);
					}
		}else {
			dbgerror("COUNTER", "[%s]: It wasn't possible to create the CNT message on node %d \n", sim_time_string(),TOS_NODE_ID );
		}
		
		//this is just to stop after a number of messages sent and have stuff more comprehensible in the log file
		if (node_counter>=MAX) {
			call MilliTimer.stop();
			dbg("COUNTER", "[%s]: Terminal %d has reached MAX and is stopping\n", sim_time_string(), TOS_NODE_ID);
		}
		
	}
	
	//function called by the Base to compute PER (as percentage of packets lost)
	void computePER (uint16_t counter, uint16_t sender ){
		int missed_recently = 0;
		//the array goes from 0 to N, while nodes are from 2 to N+2
		int index = sender - 2;
		float missed_f;
		float counter_f;
		dbg("PER", "[%s]: the base is computing PER for node %d \n", sim_time_string(), sender); 
		
		//we compare the counter of the packet we just received with the last one we memorized to see how many packet got lost
		missed_recently = counter - last_received[index] - 1;
		missed_packets[index] = missed_packets[index]+ missed_recently;
		
		//we then compute the PER as the percentage of missed packets
		missed_f = missed_packets[index];
		counter_f = counter;
		percentage_PER[index] = (missed_f / counter_f)*100;
		
		//we print the values 
		dbg("PER", "[%s]: For node %d last received was %d \n", sim_time_string(), sender, last_received[index]);
		dbg("PER", "[%s]: For node %d total missed packets are %d, ones lost since last transmission are %d \n", sim_time_string(), sender,  missed_packets[index], missed_recently);
		dbg("PER", "[%s]: For node %d the PER is %.4f %\n", sim_time_string(), sender, percentage_PER[index]); 
		
		//we then update the last received and increase the counter of total message received for the base
		last_received[index] = counter;
		base_counter = base_counter + 1 + missed_recently;
		dbg("PER", "[%s]: On base counter is %d\n", sim_time_string(), base_counter);
		//IF WE LOSE THE LAST PACKETS THAT ARE SENT BEFORE REACHING 5*MAX THIS DOENS'T WORK 
		if (base_counter > 5*MAX) {printfinalstats();}
	}
	
	void initialize_arrays() {
		//here we just set to zero the values needed to compute the PER at beginning of exec
		int i;
		for (i=0; i<N; i++){
			last_received[i]=0;
			missed_packets[i]=0;
			percentage_PER[i]=0;
		}
	}
	
	//a method that is called after we receive the expected amount of messages from all stations
	void printfinalstats(){
		int i;
		int node;
		dbg("PER", "[%s]:\n\n\n\n\nPRINTING FINAL STATS \n", sim_time_string());
		for (i=0; i<N; i++){
			node = i+2;
			dbg("PER", "[%s]: At the end for node %d the PER is %.4f %\n", sim_time_string(), node, percentage_PER[i] );
		}
	}
	

	 
}
