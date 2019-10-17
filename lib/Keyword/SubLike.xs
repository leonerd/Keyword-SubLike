/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2019 -- leonerd@leonerd.org.uk
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "lexer-additions.c.inc"

#define active_keywords_hv()  MY_active_keywords_hv(aTHX)
static HV *MY_active_keywords_hv(pTHX)
{
/* TODO: #ifdef MULTIPLICITY and look in PL_modglobal.
 */
  static HV *kw = NULL;
  if(!kw)
    kw = newHV();

  return kw;
}

#define lex_scan_parenthesized()  MY_lex_scan_parenthesized(aTHX)
static SV *MY_lex_scan_parenthesized(pTHX)
{
  I32 c;
  int parencount = 0;
  SV *ret = newSVpvs("");
  if(lex_bufutf8())
    SvUTF8_on(ret);

  c = lex_peek_unichar(0);

  while(c != -1) {
    sv_cat_c(ret, lex_read_unichar(0));

    switch(c) {
      case '(': parencount++; break;
      case ')': parencount--; break;
    }
    if(!parencount)
      break;

    c = lex_peek_unichar(0);
  }

  if(SvCUR(ret))
    return ret;

  SvREFCNT_dec(ret);
  return NULL;
}

static int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

static int my_keyword_plugin(pTHX_ char *kw, STRLEN kwlen, OP **op_ptr)
{
  SV *key = newSVpvf("%.*s", kwlen, kw);
  sv_2mortal(key);

  HE *he = hv_fetch_ent(active_keywords_hv(), key, 0, 0);
  if(!he || !HeVAL(he))
    return (*next_keyword_plugin)(aTHX_ kw, kwlen, op_ptr);

  lex_read_space(0);

  SV *name = lex_scan_ident();
  SAVEFREESV(name);

  lex_read_space(0);

  SV *parenstring = lex_scan_parenthesized();
  SAVEFREESV(parenstring);

  lex_read_space(0);

  if(lex_peek_unichar(0) != '{')
    croak("Expected a { BLOCK }");

  I32 floor_ix = start_subparse(FALSE, CVf_ANON);
  SAVEFREESV(PL_compcv);
  I32 save_ix = block_start(TRUE);

  OP *body = parse_block(0);

  SvREFCNT_inc(PL_compcv);
  body = block_end(save_ix, body);

  CV *protocv = newATTRSUB(floor_ix, NULL, NULL, NULL, body);
  SAVEFREESV(protocv);

  {
    dSP;

    ENTER;
    SAVETMPS;

    EXTEND(SP, 3);
    PUSHMARK(SP);
    PUSHs(name);
    PUSHs(parenstring);
    mPUSHs(newRV_noinc((SV *)cv_clone(protocv)));
    PUTBACK;

    call_sv(HeVAL(he), G_VOID);

    FREETMPS;
    LEAVE;
  }

  *op_ptr = newOP(OP_NULL, 0);
  return KEYWORD_PLUGIN_STMT;
}

MODULE = Keyword::SubLike    PACKAGE = Keyword::SubLike

void
sublike(kwname, body)
    char *kwname
    CV   *body
  INIT:
    SV *key;
    HE *he;
  CODE:
    key = newSVpvf("%s", kwname);
    sv_2mortal(key);

    he = hv_fetch_ent(active_keywords_hv(), key, 1, 0);
    HeVAL(he) = SvREFCNT_inc(body);

    /* TODO: SAVE a destructor for end of scope to remove it again
     */

BOOT:
  wrap_keyword_plugin(&my_keyword_plugin, &next_keyword_plugin);
