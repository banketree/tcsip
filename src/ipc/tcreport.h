#ifndef TCREPORT_H
#define TCREPORT_H
enum reg_state;
struct msgpack_packer;
struct hist_el;
struct contact_el;
struct tcsipcall;
struct uplink;
struct pl;
struct list;
struct le;

void report_reg(enum reg_state state, void*arg);
void report_call_change(struct tcsipcall* call, void *arg);
void report_call(struct tcsipcall* call, void *arg);
void report_up(struct uplink *up, int op, void*arg);
void report_msg(time_t ts, char *idx, const struct sip_addr *from, struct mbuf *data, int state, void *arg);
void report_cert(int err, struct pl*name, struct pl*uri, void*arg);
void report_lp(int err, struct pl*token, void*arg);
void report_signup(int code, struct list*, void *arg);
void report_hist(int err, char *idx, struct list*hlist, void*arg);
void report_ctlist(int err, struct list*ctlist, void*arg);
void report_histel(int err, int op, struct hist_el*, void*arg);

bool write_history_el(struct le *le, void *arg);
bool write_contact_el(struct le *le, void *arg);

#define push_str(__s) {\
    msgpack_pack_raw(pk, [__s length]);\
    msgpack_pack_raw_body(pk, _byte(__s), [__s length]);}
#define push_cstr(__c) {\
    msgpack_pack_raw(pk, sizeof(__c)-1);\
    msgpack_pack_raw_body(pk, __c, sizeof(__c)-1);}
#define push_cstr_len(__c) {\
    int tmp = strlen(__c);\
    msgpack_pack_raw(pk, tmp);\
    msgpack_pack_raw_body(pk, __c, tmp);}
#define push_pl(__c) {\
    msgpack_pack_raw(pk, __c.l);\
    msgpack_pack_raw_body(pk, __c.p, __c.l);}

#endif
