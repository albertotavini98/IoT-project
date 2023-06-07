/**
 *  @author Marco Petri and Alberto Tavini
 */

#ifndef NODE_H
#define NODE_H
#define RTS 1
#define CTS 2
#define CNT 3


//inizialmente avevamo ragionato su tre tipi di messaggi, ma penso sia più comodo usarne uno con un identificatore per il tipo di modo che la dimensione 
//è sempre la stessa e si può controllare il tipo con un if e agire di conseguenza
//1 will be RST, 2 will be LST, 3 will be actual payload message indicated by CNT (counter)
typedef nx_struct my_msg {
	nx_uint8_t type;
	nx_uint16_t counter;
	nx_uint16_t RTS_sender;
	nx_uint16_t CTS_authorized;
} my_msg_t;


enum{
	AM_MY_MSG = 6,
};

#endif

