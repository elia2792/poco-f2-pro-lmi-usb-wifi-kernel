/* SPDX-License-Identifier: GPL-2.0 */
#ifndef WMA_INJECTION_TX_STATE_H
#define WMA_INJECTION_TX_STATE_H
/* Caller holds the TX-cache lock for every operation. A submitting host
 * retains its reference even if firmware completes before send returns.
 */
enum wma_inj_tx_phase { WMA_INJ_TX_FREE, WMA_INJ_TX_SUBMITTING,
 WMA_INJ_TX_INFLIGHT, WMA_INJ_TX_COMPLETED };
struct wma_inj_tx_state {
 void *buf;
 unsigned int desc_id;
 enum wma_inj_tx_phase phase;
 int timeout_reported;
};
struct wma_inj_tx_release { void *buf; int unmap; };
static inline int wma_inj_tx_reserve(struct wma_inj_tx_state *s,
 unsigned int id, void *buf)
{
 if (s->phase != WMA_INJ_TX_FREE || !id || !buf) return 0;
 s->buf = buf; s->desc_id = id; s->phase = WMA_INJ_TX_SUBMITTING;
 s->timeout_reported = 0;
 return 1;
}
static inline struct wma_inj_tx_release
wma_inj_tx_detach(struct wma_inj_tx_state *s, int unmap)
{
 struct wma_inj_tx_release out = { s->buf, unmap };
 s->buf = 0; s->phase = WMA_INJ_TX_FREE; s->timeout_reported = 0;
 return out;
}
static inline struct wma_inj_tx_release
wma_inj_tx_submitted(struct wma_inj_tx_state *s, unsigned int id, int ok)
{
 struct wma_inj_tx_release none = { 0, 0 };
 if (s->desc_id != id || (s->phase != WMA_INJ_TX_SUBMITTING &&
                         s->phase != WMA_INJ_TX_COMPLETED)) return none;
 if (ok && s->phase == WMA_INJ_TX_SUBMITTING) {
  s->phase = WMA_INJ_TX_INFLIGHT; return none;
 }
 /* Failed transport submission has already undone any DMA mapping. */
 return wma_inj_tx_detach(s, ok);
}
static inline struct wma_inj_tx_release
wma_inj_tx_complete(struct wma_inj_tx_state *s, unsigned int id)
{
 struct wma_inj_tx_release none = { 0, 0 };
 if (s->desc_id != id) return none;
 if (s->phase == WMA_INJ_TX_SUBMITTING) {
  s->phase = WMA_INJ_TX_COMPLETED; return none;
 }
 if (s->phase == WMA_INJ_TX_INFLIGHT) return wma_inj_tx_detach(s, 1);
 return none;
}
static inline int wma_inj_tx_timeout(struct wma_inj_tx_state *s)
{
 if ((s->phase != WMA_INJ_TX_SUBMITTING && s->phase != WMA_INJ_TX_INFLIGHT) ||
     s->timeout_reported) return 0;
 s->timeout_reported = 1;
 return 1; /* Diagnostic only: a timeout does not revoke DMA ownership. */
}
static inline struct wma_inj_tx_release
wma_inj_tx_purge(struct wma_inj_tx_state *s, int hardware_stopped)
{
 struct wma_inj_tx_release none = { 0, 0 };
 if (!hardware_stopped || s->phase != WMA_INJ_TX_INFLIGHT) return none;
 return wma_inj_tx_detach(s, 1);
}
#endif
