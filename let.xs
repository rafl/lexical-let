#include "EXTERN.h"
#include "perl.h"
#include "callchecker0.h"
#include "callparser.h"
#include "XSUB.h"

#define SVt_PADNAME SVt_PVMG

#ifndef COP_SEQ_RANGE_LOW_set
# define COP_SEQ_RANGE_LOW_set(sv,val) \
  do { ((XPVNV *)SvANY(sv))->xnv_u.xpad_cop_seq.xlow = val; } while (0)
# define COP_SEQ_RANGE_HIGH_set(sv,val) \
  do { ((XPVNV *)SvANY(sv))->xnv_u.xpad_cop_seq.xhigh = val; } while (0)
#endif

#define DEMAND_IMMEDIATE 0x00000001
#define DEMAND_NOCONSUME 0x00000002
#define demand_unichar(c, f) S_demand_unichar(aTHX_ c, f)
static void
S_demand_unichar (pTHX_ I32 c, U32 flags)
{
  if(!(flags & DEMAND_IMMEDIATE))
    lex_read_space(0);

  if(lex_peek_unichar(0) != c)
    croak("syntax error");

  if(!(flags & DEMAND_NOCONSUME))
    lex_read_unichar(0);
}

#define parse_idword(prefix, prefixlen)  S_parse_idword(aTHX_ prefix, prefixlen)
static SV *
S_parse_idword (pTHX_ char const *prefix, STRLEN prefixlen)
{
  STRLEN idlen;
  SV *sv;
  char *start, *s, c;

  s = start = PL_parser->bufptr;
  c = *s;

  if (!isIDFIRST(c))
    croak("syntax error");

  do {
    c = *++s;
  } while (isALNUM(c));

  lex_read_to(s);

  idlen = s - start;

  sv = sv_2mortal(newSV(prefixlen + idlen));
  Copy(prefix, SvPVX(sv), prefixlen, char);
  Copy(start, SvPVX(sv) + prefixlen, idlen, char);
  SvPVX(sv)[prefixlen + idlen] = '\0';
  SvCUR_set(sv, prefixlen + idlen);
  SvPOK_on(sv);

  return sv;
}

typedef enum {
  VARt_UNDEF,
  VARt_SV,
  VARt_AV,
  VARt_HV
} vartype;

#define parse_varname(typep) S_parse_varname(aTHX_ typep)
static SV *
S_parse_varname (pTHX_ vartype *typep)
{
  SV *ret;
  I32 next_char = lex_peek_unichar(0);
  char prefix[2];
  vartype type;

  switch (next_char) {
  case 'u':
    type = VARt_UNDEF;
    break;
  case '$':
    type = VARt_SV;
    break;
  case '@':
    type = VARt_AV;
    break;
  case '%':
    type = VARt_HV;
    break;
  default:
    croak("syntax error");
    break;
  }

  prefix[0] = next_char;
  prefix[1] = '\0';

  lex_read_unichar(0);
  ret = parse_idword(prefix, 1);

  if (type == VARt_UNDEF && strNE(SvPVX(ret), "undef"))
    croak("syntax error");

  *typep = type;
  return ret;
}

#define pad_add_my_var_sv(type, varname) S_pad_add_my_var_sv(aTHX_ type, varname)
static PADOFFSET
S_pad_add_my_var_sv (pTHX_ vartype type, SV *varname)
{
  PADOFFSET offset;
  SV *myvar, *namesv;
  svtype sv_type;

  switch (type) {
  case VARt_SV:
    sv_type = SVt_IV;
    break;
  case VARt_AV:
    sv_type = SVt_PVAV;
    break;
  case VARt_HV:
    sv_type = SVt_PVHV;
    break;
  default:
    croak("unable to create lexical for this variable type");
    break;
  }

  myvar = *av_fetch(PL_comppad, AvFILLp(PL_comppad) + 1, 1);
  sv_upgrade(myvar, sv_type);
  offset = AvFILLp(PL_comppad);
  SvPADMY_on(myvar);

  PL_curpad = AvARRAY(PL_comppad);
  namesv = newSV_type(SVt_PADNAME);
  sv_setsv(namesv, varname);

  COP_SEQ_RANGE_LOW_set(namesv, PL_cop_seqmax);
  COP_SEQ_RANGE_HIGH_set(namesv, PERL_PADSEQ_INTRO);
  PL_cop_seqmax++;

  av_store(PL_comppad_name, offset, namesv);

  return offset;
}

#define mygenop_pad(type, varname) S_mygenop_pad(aTHX_ type, varname)
static OP *
S_mygenop_pad(pTHX_ vartype type, SV *varname)
{
  I32 optype;
  OP *pvarop;

  switch (type) {
  case VARt_UNDEF:
    return newOP(OP_UNDEF, 0);
    break;
  case VARt_SV:
    optype = OP_PADSV;
    break;
  case VARt_AV:
    optype = OP_PADAV;
    break;
  case VARt_HV:
    optype = OP_PADHV;
    break;
  }

  pvarop = newOP(optype, OPpLVAL_INTRO << 8);
  pvarop->op_targ = pad_add_my_var_sv(type, varname);

  return pvarop;
}

#define parse_varlist() S_parse_varlist(aTHX)
static OP *
S_parse_varlist (pTHX)
{
  bool had_paren = false;
  OP *ret = NULL;

  if (lex_peek_unichar(0) == '(') {
    lex_read_unichar(0);
    had_paren = true;
    lex_read_space(0);
  }

  do {
    vartype type;
    SV *varname;
    OP *padop;

    varname = parse_varname(&type);
    padop = mygenop_pad(type, varname);
    if (!ret)
      ret = had_paren ? newLISTOP(OP_LIST, 0, padop, NULL) : padop;
    else
      ret = op_append_elem(OP_LIST, ret, padop);

    if (had_paren) {
      lex_read_space(0);

      if (lex_peek_unichar(0) == ',') {
        lex_read_unichar(0);
        lex_read_space(0);
      }
    }

    lex_read_space(0);
  } while (had_paren && lex_peek_unichar(0) != ')');

  if (had_paren)
    demand_unichar(')', 0);

  return ret;
}

static OP *
myparse_args_let (pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
  int blk_floor;
  OP *blkop, *enterop, *leaveop, *initop = NULL;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(psobj);
  PERL_UNUSED_ARG(flagsp);

  blk_floor = Perl_block_start(aTHX_ 1);

  lex_read_space(0);
  while (lex_peek_unichar(0) != '{') {
    demand_unichar('(', 0);
    lex_read_space(0);

    while (lex_peek_unichar(0) != ')') {
      OP *declop = NULL, *lhs, *assignop;

      lex_read_space(0);
      lhs = parse_varlist();

      lex_read_space(0);
      if (lex_peek_unichar(0) == '=') {
        lex_read_unichar(0);
        declop = parse_fullexpr(0);
        lex_read_space(0);
      }

      if (lex_peek_unichar(0) != ')') {
        demand_unichar(';', 0);
        lex_read_space(0);
      }

      if (declop)
        assignop = newASSIGNOP(0, lhs, 0, declop);
      else /* no expr to assign */
        assignop = lhs;

      if (!initop)
        initop = newLISTOP(OP_LINESEQ, 0, assignop, NULL);
      else
        op_append_elem(OP_LINESEQ, initop, assignop);
    }

    lex_read_unichar(0);
    lex_read_space(0);
  }

  blkop = op_prepend_elem(OP_LINESEQ, initop, parse_block(0));
  blkop = Perl_block_end(aTHX_ blk_floor, blkop);

  enterop = newOP(OP_ENTER, 0);
  leaveop = newLISTOP(OP_LEAVE, 0, enterop, NULL);

  cUNOPx(leaveop)->op_first = enterop;
  enterop->op_sibling = blkop;

  return leaveop;
}

static OP *
myck_entersub_let (pTHX_ OP *entersubop, GV *namegv, SV *protosv)
{
  OP *pushop, *blkop, *rv2cvop;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(protosv);

  pushop = cUNOPx(entersubop)->op_first;
  if (!pushop->op_sibling)
    pushop = cUNOPx(pushop)->op_first;

  blkop = pushop->op_sibling;

  rv2cvop = blkop->op_sibling;
  blkop->op_sibling = NULL;
  pushop->op_sibling = rv2cvop;
  op_free(entersubop);

  return blkop;
}

MODULE = let  PACKAGE = let

PROTOTYPES: DISABLE

BOOT:
{
  CV *let_cv;

  let_cv = get_cv("let::let", 0);

  cv_set_call_parser(let_cv, myparse_args_let, &PL_sv_undef);
  cv_set_call_checker(let_cv, myck_entersub_let, (SV *)let_cv);
}
