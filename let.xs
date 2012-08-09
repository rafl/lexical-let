#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static SV *hintkey_let_sv;
static int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

#define keyword_active(sv)    S_keyword_active(aTHX_ sv)
#define keyword_enable(sv)    S_keyword_enable(aTHX_ sv)
#define keyword_disable(sv)   S_keyword_disable(aTHX_ sv)
#define parse_keyword_let()   S_parse_keyword_let(aTHX)
#define parse_let_varlist()   S_parse_let_varlist(aTHX)
#define parse_idword(prefix)  S_parse_idword(aTHX_ prefix)
#define parse_varname()       S_parse_varname(aTHX)

static int
S_keyword_active (pTHX_ SV *hintkey_sv)
{
    HE *he;

    if (!GvHV(PL_hintgv)) {
        return 0;
    }

    he = hv_fetch_ent(GvHV(PL_hintgv), hintkey_sv, 0,
                      SvSHARED_HASH(hintkey_sv));

    return he && SvTRUE(HeVAL(he));
}

static void
S_keyword_enable (pTHX_ SV *hintkey_sv)
{
    HE *he;
    SV *val_sv = newSViv(1);

    PL_hints = HINT_LOCALIZE_HH;
    gv_HVadd(PL_hintgv);

    he = hv_store_ent(GvHV(PL_hintgv), hintkey_sv, val_sv,
                      SvSHARED_HASH(hintkey_sv));

    if (he) {
        SV *val = HeVAL(he);
        SvSETMAGIC(val);
    } else {
        SvREFCNT_dec(val_sv);
    }
}

static void
S_keyword_disable (pTHX_ SV *hintkey_sv)
{
    if (GvHV(PL_hintgv)) {
        PL_hints |= HINT_LOCALIZE_HH;
        (void)hv_delete_ent(GvHV(PL_hintgv), hintkey_sv, G_DISCARD,
                            SvSHARED_HASH(hintkey_sv));
    }
}

static SV *
S_parse_idword (pTHX_ char const *prefix)
{
    STRLEN prefixlen, idlen;
    SV *sv;
    char *start, *s, c;

    s = start = PL_parser->bufptr;
    c = *s;

    if (!isIDFIRST(c)) {
        croak("syntax error");
    }

    do {
        c = *++s;
    } while (isALNUM(c));

    lex_read_to(s);

    prefixlen = strlen(prefix);
    idlen = s - start;

    sv = sv_2mortal(newSV(prefixlen + idlen));
    Copy(prefix, SvPVX(sv), prefixlen, char);
    Copy(start, SvPVX(sv) + prefixlen, idlen, char);
    SvPVX(sv)[prefixlen + idlen] = 0;
    SvCUR_set(sv, prefixlen + idlen);
    SvPOK_on(sv);

    return sv;
}

static SV *
S_parse_varname (pTHX) {
    SV *ret;
    I32 next_char = lex_peek_unichar(0);

    switch (next_char) {
    case '$':
    case '@':
    case '%': {
        char prefix[2];
        prefix[0] = next_char;
        prefix[1] = '\0';

        lex_read_unichar(0);
        ret = parse_idword(prefix);
        break;
    }
    default:
        croak("syntax error");
    }

    return ret;
}

static char *
S_parse_let_varlist (pTHX)
{
    char *ret;

    lex_read_space(0);

    while (lex_peek_unichar(0) != ')') {
        OP *op;
        SV *namesv;

        namesv = parse_varname();

        lex_read_space(0);
        if (lex_peek_unichar(0) != '=') {
            croak("= expected");
        }
        lex_read_unichar(0);
        lex_read_space(0);

        op = parse_fullstmt(0);
        sv_dump(namesv);
        op_dump(op);

        lex_read_space(0);
    }

    Newx(ret, 2, char);
    strncpy(ret, "1", 1);

    return ret;
}

static OP *
S_parse_keyword_let (pTHX)
{
    char *varstr;

    lex_read_space(0);

    if (lex_peek_unichar(0) != '(') {
        croak("( expected");
    }
    lex_read_unichar(0);

    varstr = parse_let_varlist();

    if (lex_peek_unichar(0) != ')') {
        croak(") expected");
    }
    lex_read_unichar(0);

    lex_read_space(0);

    if (lex_peek_unichar(0) != '{') {
        croak("{ expected");
    }
    //lex_read_unichar(0);

    lex_stuff_pvs(", sub ", 0);

    //    lex_stuff_pvs("->(sub", 0);

    /*    lex_read_unichar(0);
          lex_stuff_pvn(";do{42;", 7, 0);*/

    Safefree(varstr);

    return NULL;
}

static int
let_keyword_plugin (pTHX_ char *keyword_ptr, STRLEN keyword_len, OP **op_ptr)
{
    if (keyword_len == 3 && strnEQ(keyword_ptr, "let", 3)
        && keyword_active(hintkey_let_sv)) {
        *op_ptr = parse_keyword_let();
        return KEYWORD_PLUGIN_EXPR;
    }

    return next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);
}


MODULE = let  PACKAGE = let

PROTOTYPES: DISABLE

BOOT:
    hintkey_let_sv = newSVpvs_share("let/let");
    next_keyword_plugin = PL_keyword_plugin;
    PL_keyword_plugin = let_keyword_plugin;

void
import (SV *klass)
PPCODE:
    PERL_UNUSED_VAR(klass);
    keyword_enable(hintkey_let_sv);

void
unimport (SV *klass)
PPCODE:
    PERL_UNUSED_VAR(klass);
    keyword_disable(hintkey_let_sv);
