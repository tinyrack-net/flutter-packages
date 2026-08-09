import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_web_links.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('WebLinksAddon pinned upstream corpus', () {
    test('.ac', () => _verifyHost('foo.ac'));
    test('.ad', () => _verifyHost('foo.ad'));
    test('.ae', () => _verifyHost('foo.ae'));
    test('.af', () => _verifyHost('foo.af'));
    test('.ag', () => _verifyHost('foo.ag'));
    test('.ai', () => _verifyHost('foo.ai'));
    test('.al', () => _verifyHost('foo.al'));
    test('.am', () => _verifyHost('foo.am'));
    test('.ao', () => _verifyHost('foo.ao'));
    test('.aq', () => _verifyHost('foo.aq'));
    test('.ar', () => _verifyHost('foo.ar'));
    test('.as', () => _verifyHost('foo.as'));
    test('.at', () => _verifyHost('foo.at'));
    test('.au', () => _verifyHost('foo.au'));
    test('.aw', () => _verifyHost('foo.aw'));
    test('.ax', () => _verifyHost('foo.ax'));
    test('.az', () => _verifyHost('foo.az'));
    test('.ba', () => _verifyHost('foo.ba'));
    test('.bb', () => _verifyHost('foo.bb'));
    test('.bd', () => _verifyHost('foo.bd'));
    test('.be', () => _verifyHost('foo.be'));
    test('.bf', () => _verifyHost('foo.bf'));
    test('.bg', () => _verifyHost('foo.bg'));
    test('.bh', () => _verifyHost('foo.bh'));
    test('.bi', () => _verifyHost('foo.bi'));
    test('.bj', () => _verifyHost('foo.bj'));
    test('.bm', () => _verifyHost('foo.bm'));
    test('.bn', () => _verifyHost('foo.bn'));
    test('.bo', () => _verifyHost('foo.bo'));
    test('.bq', () => _verifyHost('foo.bq'));
    test('.br', () => _verifyHost('foo.br'));
    test('.bs', () => _verifyHost('foo.bs'));
    test('.bt', () => _verifyHost('foo.bt'));
    test('.bw', () => _verifyHost('foo.bw'));
    test('.by', () => _verifyHost('foo.by'));
    test('.bz', () => _verifyHost('foo.bz'));
    test('.ca', () => _verifyHost('foo.ca'));
    test('.cc', () => _verifyHost('foo.cc'));
    test('.cd', () => _verifyHost('foo.cd'));
    test('.cf', () => _verifyHost('foo.cf'));
    test('.cg', () => _verifyHost('foo.cg'));
    test('.ch', () => _verifyHost('foo.ch'));
    test('.ci', () => _verifyHost('foo.ci'));
    test('.ck', () => _verifyHost('foo.ck'));
    test('.cl', () => _verifyHost('foo.cl'));
    test('.cm', () => _verifyHost('foo.cm'));
    test('.cn', () => _verifyHost('foo.cn'));
    test('.co', () => _verifyHost('foo.co'));
    test('.com', () => _verifyHost('foo.com'));
    test('.com.ac', () => _verifyHost('foo.com.ac'));
    test('.com.ad', () => _verifyHost('foo.com.ad'));
    test('.com.ae', () => _verifyHost('foo.com.ae'));
    test('.com.af', () => _verifyHost('foo.com.af'));
    test('.com.ag', () => _verifyHost('foo.com.ag'));
    test('.com.ai', () => _verifyHost('foo.com.ai'));
    test('.com.al', () => _verifyHost('foo.com.al'));
    test('.com.am', () => _verifyHost('foo.com.am'));
    test('.com.ao', () => _verifyHost('foo.com.ao'));
    test('.com.aq', () => _verifyHost('foo.com.aq'));
    test('.com.ar', () => _verifyHost('foo.com.ar'));
    test('.com.as', () => _verifyHost('foo.com.as'));
    test('.com.at', () => _verifyHost('foo.com.at'));
    test('.com.au', () => _verifyHost('foo.com.au'));
    test('.com.aw', () => _verifyHost('foo.com.aw'));
    test('.com.ax', () => _verifyHost('foo.com.ax'));
    test('.com.az', () => _verifyHost('foo.com.az'));
    test('.com.ba', () => _verifyHost('foo.com.ba'));
    test('.com.bb', () => _verifyHost('foo.com.bb'));
    test('.com.bd', () => _verifyHost('foo.com.bd'));
    test('.com.be', () => _verifyHost('foo.com.be'));
    test('.com.bf', () => _verifyHost('foo.com.bf'));
    test('.com.bg', () => _verifyHost('foo.com.bg'));
    test('.com.bh', () => _verifyHost('foo.com.bh'));
    test('.com.bi', () => _verifyHost('foo.com.bi'));
    test('.com.bj', () => _verifyHost('foo.com.bj'));
    test('.com.bm', () => _verifyHost('foo.com.bm'));
    test('.com.bn', () => _verifyHost('foo.com.bn'));
    test('.com.bo', () => _verifyHost('foo.com.bo'));
    test('.com.bq', () => _verifyHost('foo.com.bq'));
    test('.com.br', () => _verifyHost('foo.com.br'));
    test('.com.bs', () => _verifyHost('foo.com.bs'));
    test('.com.bt', () => _verifyHost('foo.com.bt'));
    test('.com.bw', () => _verifyHost('foo.com.bw'));
    test('.com.by', () => _verifyHost('foo.com.by'));
    test('.com.bz', () => _verifyHost('foo.com.bz'));
    test('.com.ca', () => _verifyHost('foo.com.ca'));
    test('.com.cc', () => _verifyHost('foo.com.cc'));
    test('.com.cd', () => _verifyHost('foo.com.cd'));
    test('.com.cf', () => _verifyHost('foo.com.cf'));
    test('.com.cg', () => _verifyHost('foo.com.cg'));
    test('.com.ch', () => _verifyHost('foo.com.ch'));
    test('.com.ci', () => _verifyHost('foo.com.ci'));
    test('.com.ck', () => _verifyHost('foo.com.ck'));
    test('.com.cl', () => _verifyHost('foo.com.cl'));
    test('.com.cm', () => _verifyHost('foo.com.cm'));
    test('.com.cn', () => _verifyHost('foo.com.cn'));
    test('.com.co', () => _verifyHost('foo.com.co'));
    test('.com.cr', () => _verifyHost('foo.com.cr'));
    test('.com.cu', () => _verifyHost('foo.com.cu'));
    test('.com.cv', () => _verifyHost('foo.com.cv'));
    test('.com.cw', () => _verifyHost('foo.com.cw'));
    test('.com.cx', () => _verifyHost('foo.com.cx'));
    test('.com.cy', () => _verifyHost('foo.com.cy'));
    test('.com.cz', () => _verifyHost('foo.com.cz'));
    test('.com.de', () => _verifyHost('foo.com.de'));
    test('.com.dj', () => _verifyHost('foo.com.dj'));
    test('.com.dk', () => _verifyHost('foo.com.dk'));
    test('.com.dm', () => _verifyHost('foo.com.dm'));
    test('.com.do', () => _verifyHost('foo.com.do'));
    test('.com.dz', () => _verifyHost('foo.com.dz'));
    test('.com.ec', () => _verifyHost('foo.com.ec'));
    test('.com.ee', () => _verifyHost('foo.com.ee'));
    test('.com.eg', () => _verifyHost('foo.com.eg'));
    test('.com.eh', () => _verifyHost('foo.com.eh'));
    test('.com.er', () => _verifyHost('foo.com.er'));
    test('.com.es', () => _verifyHost('foo.com.es'));
    test('.com.et', () => _verifyHost('foo.com.et'));
    test('.com.eu', () => _verifyHost('foo.com.eu'));
    test('.com.fi', () => _verifyHost('foo.com.fi'));
    test('.com.fj', () => _verifyHost('foo.com.fj'));
    test('.com.fk', () => _verifyHost('foo.com.fk'));
    test('.com.fm', () => _verifyHost('foo.com.fm'));
    test('.com.fo', () => _verifyHost('foo.com.fo'));
    test('.com.fr', () => _verifyHost('foo.com.fr'));
    test('.com.ga', () => _verifyHost('foo.com.ga'));
    test('.com.gd', () => _verifyHost('foo.com.gd'));
    test('.com.ge', () => _verifyHost('foo.com.ge'));
    test('.com.gf', () => _verifyHost('foo.com.gf'));
    test('.com.gg', () => _verifyHost('foo.com.gg'));
    test('.com.gh', () => _verifyHost('foo.com.gh'));
    test('.com.gi', () => _verifyHost('foo.com.gi'));
    test('.com.gl', () => _verifyHost('foo.com.gl'));
    test('.com.gm', () => _verifyHost('foo.com.gm'));
    test('.com.gn', () => _verifyHost('foo.com.gn'));
    test('.com.gp', () => _verifyHost('foo.com.gp'));
    test('.com.gq', () => _verifyHost('foo.com.gq'));
    test('.com.gr', () => _verifyHost('foo.com.gr'));
    test('.com.gs', () => _verifyHost('foo.com.gs'));
    test('.com.gt', () => _verifyHost('foo.com.gt'));
    test('.com.gu', () => _verifyHost('foo.com.gu'));
    test('.com.gw', () => _verifyHost('foo.com.gw'));
    test('.com.gy', () => _verifyHost('foo.com.gy'));
    test('.com.hk', () => _verifyHost('foo.com.hk'));
    test('.com.hm', () => _verifyHost('foo.com.hm'));
    test('.com.hn', () => _verifyHost('foo.com.hn'));
    test('.com.hr', () => _verifyHost('foo.com.hr'));
    test('.com.ht', () => _verifyHost('foo.com.ht'));
    test('.com.hu', () => _verifyHost('foo.com.hu'));
    test('.com.id', () => _verifyHost('foo.com.id'));
    test('.com.ie', () => _verifyHost('foo.com.ie'));
    test('.com.il', () => _verifyHost('foo.com.il'));
    test('.com.im', () => _verifyHost('foo.com.im'));
    test('.com.in', () => _verifyHost('foo.com.in'));
    test('.com.io', () => _verifyHost('foo.com.io'));
    test('.com.iq', () => _verifyHost('foo.com.iq'));
    test('.com.ir', () => _verifyHost('foo.com.ir'));
    test('.com.is', () => _verifyHost('foo.com.is'));
    test('.com.it', () => _verifyHost('foo.com.it'));
    test('.com.je', () => _verifyHost('foo.com.je'));
    test('.com.jm', () => _verifyHost('foo.com.jm'));
    test('.com.jo', () => _verifyHost('foo.com.jo'));
    test('.com.jp', () => _verifyHost('foo.com.jp'));
    test('.com.ke', () => _verifyHost('foo.com.ke'));
    test('.com.kg', () => _verifyHost('foo.com.kg'));
    test('.com.kh', () => _verifyHost('foo.com.kh'));
    test('.com.ki', () => _verifyHost('foo.com.ki'));
    test('.com.km', () => _verifyHost('foo.com.km'));
    test('.com.kn', () => _verifyHost('foo.com.kn'));
    test('.com.kp', () => _verifyHost('foo.com.kp'));
    test('.com.kr', () => _verifyHost('foo.com.kr'));
    test('.com.kw', () => _verifyHost('foo.com.kw'));
    test('.com.ky', () => _verifyHost('foo.com.ky'));
    test('.com.kz', () => _verifyHost('foo.com.kz'));
    test('.com.la', () => _verifyHost('foo.com.la'));
    test('.com.lb', () => _verifyHost('foo.com.lb'));
    test('.com.lc', () => _verifyHost('foo.com.lc'));
    test('.com.li', () => _verifyHost('foo.com.li'));
    test('.com.lk', () => _verifyHost('foo.com.lk'));
    test('.com.lr', () => _verifyHost('foo.com.lr'));
    test('.com.ls', () => _verifyHost('foo.com.ls'));
    test('.com.lt', () => _verifyHost('foo.com.lt'));
    test('.com.lu', () => _verifyHost('foo.com.lu'));
    test('.com.lv', () => _verifyHost('foo.com.lv'));
    test('.com.ly', () => _verifyHost('foo.com.ly'));
    test('.com.ma', () => _verifyHost('foo.com.ma'));
    test('.com.mc', () => _verifyHost('foo.com.mc'));
    test('.com.md', () => _verifyHost('foo.com.md'));
    test('.com.me', () => _verifyHost('foo.com.me'));
    test('.com.mg', () => _verifyHost('foo.com.mg'));
    test('.com.mh', () => _verifyHost('foo.com.mh'));
    test('.com.mk', () => _verifyHost('foo.com.mk'));
    test('.com.ml', () => _verifyHost('foo.com.ml'));
    test('.com.mm', () => _verifyHost('foo.com.mm'));
    test('.com.mn', () => _verifyHost('foo.com.mn'));
    test('.com.mo', () => _verifyHost('foo.com.mo'));
    test('.com.mp', () => _verifyHost('foo.com.mp'));
    test('.com.mq', () => _verifyHost('foo.com.mq'));
    test('.com.mr', () => _verifyHost('foo.com.mr'));
    test('.com.ms', () => _verifyHost('foo.com.ms'));
    test('.com.mt', () => _verifyHost('foo.com.mt'));
    test('.com.mu', () => _verifyHost('foo.com.mu'));
    test('.com.mv', () => _verifyHost('foo.com.mv'));
    test('.com.mw', () => _verifyHost('foo.com.mw'));
    test('.com.mx', () => _verifyHost('foo.com.mx'));
    test('.com.my', () => _verifyHost('foo.com.my'));
    test('.com.mz', () => _verifyHost('foo.com.mz'));
    test('.com.na', () => _verifyHost('foo.com.na'));
    test('.com.nc', () => _verifyHost('foo.com.nc'));
    test('.com.ne', () => _verifyHost('foo.com.ne'));
    test('.com.nf', () => _verifyHost('foo.com.nf'));
    test('.com.ng', () => _verifyHost('foo.com.ng'));
    test('.com.ni', () => _verifyHost('foo.com.ni'));
    test('.com.nl', () => _verifyHost('foo.com.nl'));
    test('.com.no', () => _verifyHost('foo.com.no'));
    test('.com.np', () => _verifyHost('foo.com.np'));
    test('.com.nr', () => _verifyHost('foo.com.nr'));
    test('.com.nu', () => _verifyHost('foo.com.nu'));
    test('.com.nz', () => _verifyHost('foo.com.nz'));
    test('.com.om', () => _verifyHost('foo.com.om'));
    test('.com.pa', () => _verifyHost('foo.com.pa'));
    test('.com.pe', () => _verifyHost('foo.com.pe'));
    test('.com.pf', () => _verifyHost('foo.com.pf'));
    test('.com.pg', () => _verifyHost('foo.com.pg'));
    test('.com.ph', () => _verifyHost('foo.com.ph'));
    test('.com.pk', () => _verifyHost('foo.com.pk'));
    test('.com.pl', () => _verifyHost('foo.com.pl'));
    test('.com.pm', () => _verifyHost('foo.com.pm'));
    test('.com.pn', () => _verifyHost('foo.com.pn'));
    test('.com.pr', () => _verifyHost('foo.com.pr'));
    test('.com.ps', () => _verifyHost('foo.com.ps'));
    test('.com.pt', () => _verifyHost('foo.com.pt'));
    test('.com.pw', () => _verifyHost('foo.com.pw'));
    test('.com.py', () => _verifyHost('foo.com.py'));
    test('.com.qa', () => _verifyHost('foo.com.qa'));
    test('.com.re', () => _verifyHost('foo.com.re'));
    test('.com.ro', () => _verifyHost('foo.com.ro'));
    test('.com.rs', () => _verifyHost('foo.com.rs'));
    test('.com.ru', () => _verifyHost('foo.com.ru'));
    test('.com.rw', () => _verifyHost('foo.com.rw'));
    test('.com.sa', () => _verifyHost('foo.com.sa'));
    test('.com.sb', () => _verifyHost('foo.com.sb'));
    test('.com.sc', () => _verifyHost('foo.com.sc'));
    test('.com.sd', () => _verifyHost('foo.com.sd'));
    test('.com.se', () => _verifyHost('foo.com.se'));
    test('.com.sg', () => _verifyHost('foo.com.sg'));
    test('.com.sh', () => _verifyHost('foo.com.sh'));
    test('.com.si', () => _verifyHost('foo.com.si'));
    test('.com.sk', () => _verifyHost('foo.com.sk'));
    test('.com.sl', () => _verifyHost('foo.com.sl'));
    test('.com.sm', () => _verifyHost('foo.com.sm'));
    test('.com.sn', () => _verifyHost('foo.com.sn'));
    test('.com.so', () => _verifyHost('foo.com.so'));
    test('.com.sr', () => _verifyHost('foo.com.sr'));
    test('.com.ss', () => _verifyHost('foo.com.ss'));
    test('.com.st', () => _verifyHost('foo.com.st'));
    test('.com.su', () => _verifyHost('foo.com.su'));
    test('.com.sv', () => _verifyHost('foo.com.sv'));
    test('.com.sx', () => _verifyHost('foo.com.sx'));
    test('.com.sy', () => _verifyHost('foo.com.sy'));
    test('.com.sz', () => _verifyHost('foo.com.sz'));
    test('.com.tc', () => _verifyHost('foo.com.tc'));
    test('.com.td', () => _verifyHost('foo.com.td'));
    test('.com.tf', () => _verifyHost('foo.com.tf'));
    test('.com.tg', () => _verifyHost('foo.com.tg'));
    test('.com.th', () => _verifyHost('foo.com.th'));
    test('.com.tj', () => _verifyHost('foo.com.tj'));
    test('.com.tk', () => _verifyHost('foo.com.tk'));
    test('.com.tl', () => _verifyHost('foo.com.tl'));
    test('.com.tm', () => _verifyHost('foo.com.tm'));
    test('.com.tn', () => _verifyHost('foo.com.tn'));
    test('.com.to', () => _verifyHost('foo.com.to'));
    test('.com.tr', () => _verifyHost('foo.com.tr'));
    test('.com.tt', () => _verifyHost('foo.com.tt'));
    test('.com.tv', () => _verifyHost('foo.com.tv'));
    test('.com.tw', () => _verifyHost('foo.com.tw'));
    test('.com.tz', () => _verifyHost('foo.com.tz'));
    test('.com.ua', () => _verifyHost('foo.com.ua'));
    test('.com.ug', () => _verifyHost('foo.com.ug'));
    test('.com.uk', () => _verifyHost('foo.com.uk'));
    test('.com.us', () => _verifyHost('foo.com.us'));
    test('.com.uy', () => _verifyHost('foo.com.uy'));
    test('.com.uz', () => _verifyHost('foo.com.uz'));
    test('.com.va', () => _verifyHost('foo.com.va'));
    test('.com.vc', () => _verifyHost('foo.com.vc'));
    test('.com.ve', () => _verifyHost('foo.com.ve'));
    test('.com.vg', () => _verifyHost('foo.com.vg'));
    test('.com.vi', () => _verifyHost('foo.com.vi'));
    test('.com.vn', () => _verifyHost('foo.com.vn'));
    test('.com.vu', () => _verifyHost('foo.com.vu'));
    test('.com.wf', () => _verifyHost('foo.com.wf'));
    test('.com.ws', () => _verifyHost('foo.com.ws'));
    test('.com.ye', () => _verifyHost('foo.com.ye'));
    test('.com.yt', () => _verifyHost('foo.com.yt'));
    test('.com.za', () => _verifyHost('foo.com.za'));
    test('.com.zm', () => _verifyHost('foo.com.zm'));
    test('.com.zw', () => _verifyHost('foo.com.zw'));
    test('.cr', () => _verifyHost('foo.cr'));
    test('.cu', () => _verifyHost('foo.cu'));
    test('.cv', () => _verifyHost('foo.cv'));
    test('.cw', () => _verifyHost('foo.cw'));
    test('.cx', () => _verifyHost('foo.cx'));
    test('.cy', () => _verifyHost('foo.cy'));
    test('.cz', () => _verifyHost('foo.cz'));
    test('.de', () => _verifyHost('foo.de'));
    test('.dj', () => _verifyHost('foo.dj'));
    test('.dk', () => _verifyHost('foo.dk'));
    test('.dm', () => _verifyHost('foo.dm'));
    test('.do', () => _verifyHost('foo.do'));
    test('.dz', () => _verifyHost('foo.dz'));
    test('.ec', () => _verifyHost('foo.ec'));
    test('.ee', () => _verifyHost('foo.ee'));
    test('.eg', () => _verifyHost('foo.eg'));
    test('.eh', () => _verifyHost('foo.eh'));
    test('.er', () => _verifyHost('foo.er'));
    test('.es', () => _verifyHost('foo.es'));
    test('.et', () => _verifyHost('foo.et'));
    test('.eu', () => _verifyHost('foo.eu'));
    test('.fi', () => _verifyHost('foo.fi'));
    test('.fj', () => _verifyHost('foo.fj'));
    test('.fk', () => _verifyHost('foo.fk'));
    test('.fm', () => _verifyHost('foo.fm'));
    test('.fo', () => _verifyHost('foo.fo'));
    test('.fr', () => _verifyHost('foo.fr'));
    test('.ga', () => _verifyHost('foo.ga'));
    test('.gd', () => _verifyHost('foo.gd'));
    test('.ge', () => _verifyHost('foo.ge'));
    test('.gf', () => _verifyHost('foo.gf'));
    test('.gg', () => _verifyHost('foo.gg'));
    test('.gh', () => _verifyHost('foo.gh'));
    test('.gi', () => _verifyHost('foo.gi'));
    test('.gl', () => _verifyHost('foo.gl'));
    test('.gm', () => _verifyHost('foo.gm'));
    test('.gn', () => _verifyHost('foo.gn'));
    test('.gp', () => _verifyHost('foo.gp'));
    test('.gq', () => _verifyHost('foo.gq'));
    test('.gr', () => _verifyHost('foo.gr'));
    test('.gs', () => _verifyHost('foo.gs'));
    test('.gt', () => _verifyHost('foo.gt'));
    test('.gu', () => _verifyHost('foo.gu'));
    test('.gw', () => _verifyHost('foo.gw'));
    test('.gy', () => _verifyHost('foo.gy'));
    test('.hk', () => _verifyHost('foo.hk'));
    test('.hm', () => _verifyHost('foo.hm'));
    test('.hn', () => _verifyHost('foo.hn'));
    test('.hr', () => _verifyHost('foo.hr'));
    test('.ht', () => _verifyHost('foo.ht'));
    test('.hu', () => _verifyHost('foo.hu'));
    test('.id', () => _verifyHost('foo.id'));
    test('.ie', () => _verifyHost('foo.ie'));
    test('.il', () => _verifyHost('foo.il'));
    test('.im', () => _verifyHost('foo.im'));
    test('.in', () => _verifyHost('foo.in'));
    test('.io', () => _verifyHost('foo.io'));
    test('.iq', () => _verifyHost('foo.iq'));
    test('.ir', () => _verifyHost('foo.ir'));
    test('.is', () => _verifyHost('foo.is'));
    test('.it', () => _verifyHost('foo.it'));
    test('.je', () => _verifyHost('foo.je'));
    test('.jm', () => _verifyHost('foo.jm'));
    test('.jo', () => _verifyHost('foo.jo'));
    test('.jp', () => _verifyHost('foo.jp'));
    test('.ke', () => _verifyHost('foo.ke'));
    test('.kg', () => _verifyHost('foo.kg'));
    test('.kh', () => _verifyHost('foo.kh'));
    test('.ki', () => _verifyHost('foo.ki'));
    test('.km', () => _verifyHost('foo.km'));
    test('.kn', () => _verifyHost('foo.kn'));
    test('.kp', () => _verifyHost('foo.kp'));
    test('.kr', () => _verifyHost('foo.kr'));
    test('.kw', () => _verifyHost('foo.kw'));
    test('.ky', () => _verifyHost('foo.ky'));
    test('.kz', () => _verifyHost('foo.kz'));
    test('.la', () => _verifyHost('foo.la'));
    test('.lb', () => _verifyHost('foo.lb'));
    test('.lc', () => _verifyHost('foo.lc'));
    test('.li', () => _verifyHost('foo.li'));
    test('.lk', () => _verifyHost('foo.lk'));
    test('.lr', () => _verifyHost('foo.lr'));
    test('.ls', () => _verifyHost('foo.ls'));
    test('.lt', () => _verifyHost('foo.lt'));
    test('.lu', () => _verifyHost('foo.lu'));
    test('.lv', () => _verifyHost('foo.lv'));
    test('.ly', () => _verifyHost('foo.ly'));
    test('.ma', () => _verifyHost('foo.ma'));
    test('.mc', () => _verifyHost('foo.mc'));
    test('.md', () => _verifyHost('foo.md'));
    test('.me', () => _verifyHost('foo.me'));
    test('.mg', () => _verifyHost('foo.mg'));
    test('.mh', () => _verifyHost('foo.mh'));
    test('.mk', () => _verifyHost('foo.mk'));
    test('.ml', () => _verifyHost('foo.ml'));
    test('.mm', () => _verifyHost('foo.mm'));
    test('.mn', () => _verifyHost('foo.mn'));
    test('.mo', () => _verifyHost('foo.mo'));
    test('.mp', () => _verifyHost('foo.mp'));
    test('.mq', () => _verifyHost('foo.mq'));
    test('.mr', () => _verifyHost('foo.mr'));
    test('.ms', () => _verifyHost('foo.ms'));
    test('.mt', () => _verifyHost('foo.mt'));
    test('.mu', () => _verifyHost('foo.mu'));
    test('.mv', () => _verifyHost('foo.mv'));
    test('.mw', () => _verifyHost('foo.mw'));
    test('.mx', () => _verifyHost('foo.mx'));
    test('.my', () => _verifyHost('foo.my'));
    test('.mz', () => _verifyHost('foo.mz'));
    test('.na', () => _verifyHost('foo.na'));
    test('.nc', () => _verifyHost('foo.nc'));
    test('.ne', () => _verifyHost('foo.ne'));
    test('.nf', () => _verifyHost('foo.nf'));
    test('.ng', () => _verifyHost('foo.ng'));
    test('.ni', () => _verifyHost('foo.ni'));
    test('.nl', () => _verifyHost('foo.nl'));
    test('.no', () => _verifyHost('foo.no'));
    test('.np', () => _verifyHost('foo.np'));
    test('.nr', () => _verifyHost('foo.nr'));
    test('.nu', () => _verifyHost('foo.nu'));
    test('.nz', () => _verifyHost('foo.nz'));
    test('.om', () => _verifyHost('foo.om'));
    test('.pa', () => _verifyHost('foo.pa'));
    test('.pe', () => _verifyHost('foo.pe'));
    test('.pf', () => _verifyHost('foo.pf'));
    test('.pg', () => _verifyHost('foo.pg'));
    test('.ph', () => _verifyHost('foo.ph'));
    test('.pk', () => _verifyHost('foo.pk'));
    test('.pl', () => _verifyHost('foo.pl'));
    test('.pm', () => _verifyHost('foo.pm'));
    test('.pn', () => _verifyHost('foo.pn'));
    test('.pr', () => _verifyHost('foo.pr'));
    test('.ps', () => _verifyHost('foo.ps'));
    test('.pt', () => _verifyHost('foo.pt'));
    test('.pw', () => _verifyHost('foo.pw'));
    test('.py', () => _verifyHost('foo.py'));
    test('.qa', () => _verifyHost('foo.qa'));
    test('.re', () => _verifyHost('foo.re'));
    test('.ro', () => _verifyHost('foo.ro'));
    test('.rs', () => _verifyHost('foo.rs'));
    test('.ru', () => _verifyHost('foo.ru'));
    test('.rw', () => _verifyHost('foo.rw'));
    test('.sa', () => _verifyHost('foo.sa'));
    test('.sb', () => _verifyHost('foo.sb'));
    test('.sc', () => _verifyHost('foo.sc'));
    test('.sd', () => _verifyHost('foo.sd'));
    test('.se', () => _verifyHost('foo.se'));
    test('.sg', () => _verifyHost('foo.sg'));
    test('.sh', () => _verifyHost('foo.sh'));
    test('.si', () => _verifyHost('foo.si'));
    test('.sk', () => _verifyHost('foo.sk'));
    test('.sl', () => _verifyHost('foo.sl'));
    test('.sm', () => _verifyHost('foo.sm'));
    test('.sn', () => _verifyHost('foo.sn'));
    test('.so', () => _verifyHost('foo.so'));
    test('.sr', () => _verifyHost('foo.sr'));
    test('.ss', () => _verifyHost('foo.ss'));
    test('.st', () => _verifyHost('foo.st'));
    test('.su', () => _verifyHost('foo.su'));
    test('.sv', () => _verifyHost('foo.sv'));
    test('.sx', () => _verifyHost('foo.sx'));
    test('.sy', () => _verifyHost('foo.sy'));
    test('.sz', () => _verifyHost('foo.sz'));
    test('.tc', () => _verifyHost('foo.tc'));
    test('.td', () => _verifyHost('foo.td'));
    test('.tf', () => _verifyHost('foo.tf'));
    test('.tg', () => _verifyHost('foo.tg'));
    test('.th', () => _verifyHost('foo.th'));
    test('.tj', () => _verifyHost('foo.tj'));
    test('.tk', () => _verifyHost('foo.tk'));
    test('.tl', () => _verifyHost('foo.tl'));
    test('.tm', () => _verifyHost('foo.tm'));
    test('.tn', () => _verifyHost('foo.tn'));
    test('.to', () => _verifyHost('foo.to'));
    test('.tr', () => _verifyHost('foo.tr'));
    test('.tt', () => _verifyHost('foo.tt'));
    test('.tv', () => _verifyHost('foo.tv'));
    test('.tw', () => _verifyHost('foo.tw'));
    test('.tz', () => _verifyHost('foo.tz'));
    test('.ua', () => _verifyHost('foo.ua'));
    test('.ug', () => _verifyHost('foo.ug'));
    test('.uk', () => _verifyHost('foo.uk'));
    test('.us', () => _verifyHost('foo.us'));
    test('.uy', () => _verifyHost('foo.uy'));
    test('.uz', () => _verifyHost('foo.uz'));
    test('.va', () => _verifyHost('foo.va'));
    test('.vc', () => _verifyHost('foo.vc'));
    test('.ve', () => _verifyHost('foo.ve'));
    test('.vg', () => _verifyHost('foo.vg'));
    test('.vi', () => _verifyHost('foo.vi'));
    test('.vn', () => _verifyHost('foo.vn'));
    test('.vu', () => _verifyHost('foo.vu'));
    test('.wf', () => _verifyHost('foo.wf'));
    test('.ws', () => _verifyHost('foo.ws'));
    test('.ye', () => _verifyHost('foo.ye'));
    test('.yt', () => _verifyHost('foo.yt'));
    test('.za', () => _verifyHost('foo.za'));
    test('.zm', () => _verifyHost('foo.zm'));
    test('.zw', () => _verifyHost('foo.zw'));
    test('all half width', _verifyAllHalfWidth);
    test('full width within url and before', _verifyFullWidthWithinUrl);
    test(
      'name + password url after full width and combining',
      _verifyCredentialsAfterCombining,
    );
    test('uppercase in protocol and host, default ports', _verifyUppercase);
    test('url after full width', _verifyUrlAfterFullWidth);
    test('url encoded params work properly', _verifyEncodedParams);
  });
}

Future<void> _verifyHost(String host) async {
  final fixture = await _fixture(
    '  http://$host  \r\n'
    '  http://$host/a~b#c~d?e~f  \r\n'
    '  http://$host/colon:test  \r\n'
    '  http://$host/colon:test:  \r\n'
    '"http://$host/"\r\n'
    "'http://$host/'\r\n"
    'http://$host/subpath/+/id',
  );
  try {
    final expected = <String>[
      'http://$host',
      'http://$host/a~b#c~d?e~f',
      'http://$host/colon:test',
      'http://$host/colon:test',
      'http://$host/',
      'http://$host/',
      'http://$host/subpath/+/id',
    ];
    for (var row = 1; row <= expected.length; row++) {
      final links = await fixture.provider.provideLinks(row);
      expect(links.map((link) => link.text), contains(expected[row - 1]));
    }
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyAllHalfWidth() async {
  final fixture = await _fixture(
    'aaa http://example.com aaa http://example.com aaa',
  );
  try {
    final links = await fixture.provider.provideLinks(1);
    expect(links, hasLength(2));
    expect(links[0].text, 'http://example.com');
    expect(links[0].range, _range(5, 1, 22, 1));
    expect(links[1].range, _range(28, 1, 5, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyUrlAfterFullWidth() async {
  final fixture = await _fixture(
    '￥￥￥ http://example.com ￥￥￥ http://example.com aaa',
  );
  try {
    final links = await fixture.provider.provideLinks(1);
    expect(links, hasLength(2));
    expect(links[0].range, _range(8, 1, 25, 1));
    expect(links[1].range, _range(34, 1, 11, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyFullWidthWithinUrl() async {
  const uri = 'https://ko.wikipedia.org/wiki/위키백과:대문';
  final fixture = await _fixture('￥￥￥ $uri aaa $uri ￥￥￥');
  try {
    final links = await fixture.provider.provideLinks(1);
    expect(links, hasLength(2));
    expect(links[0].text, uri);
    expect(links[0].range, _range(8, 1, 11, 2));
    final wrappedLinks = await fixture.provider.provideLinks(2);
    expect(wrappedLinks, hasLength(2));
    expect(wrappedLinks[1].text, uri);
    expect(wrappedLinks[1].range, _range(17, 2, 19, 3));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyCredentialsAfterCombining() async {
  const uri = 'http://test:password@example.com/some_path';
  final fixture = await _fixture('￥￥￥cafe\u0301 $uri');
  try {
    final link = (await fixture.provider.provideLinks(1)).single;
    expect(link.text, uri);
    expect(link.range, _range(12, 1, 13, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyEncodedParams() async {
  const uri = 'http://test:password@example.com/some_path?param=1%202%3';
  final fixture = await _fixture('￥￥￥cafe\u0301 $uri');
  try {
    final link = (await fixture.provider.provideLinks(1)).single;
    expect(link.text, uri);
    expect(link.range, _range(12, 1, 27, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyUppercase() async {
  const expected = <String>[
    'HTTP://EXAMPLE.COM',
    'HTTPS://Example.com',
    'HTTP://Example.com:80',
    'HTTP://Example.com:80/staysUpper',
    'HTTP://Ab:xY@abc.com:80/staysUpper',
  ];
  final fixture = await _fixture('${expected.join('  \r\n  ')}  ');
  try {
    for (var row = 1; row <= expected.length; row++) {
      final links = await fixture.provider.provideLinks(row);
      expect(links.map((link) => link.text), contains(expected[row - 1]));
    }
  } finally {
    fixture.dispose();
  }
}

Future<
  ({Terminal terminal, TerminalLinkProvider provider, void Function() dispose})
>
_fixture(String text) async {
  final terminal = Terminal(options: TerminalOptions(cols: 40, rows: 10));
  final addon = WebLinksAddon(handler: (_, _) {});
  terminal.loadAddon(addon);
  await terminal.writeAndWait(text);
  return (
    terminal: terminal,
    provider: terminal.linkProviders.last,
    dispose: () {
      addon.dispose();
      terminal.dispose();
    },
  );
}

TerminalBufferRange _range(int startX, int startY, int endX, int endY) =>
    TerminalBufferRange(
      start: TerminalBufferPosition(startX, startY),
      end: TerminalBufferPosition(endX, endY),
    );
