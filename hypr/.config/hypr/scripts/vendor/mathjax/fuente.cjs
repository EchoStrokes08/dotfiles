const {mathjax} = require('mathjax-full/js/mathjax.js');
const {TeX} = require('mathjax-full/js/input/tex.js');
const {SVG} = require('mathjax-full/js/output/svg.js');
const {liteAdaptor} = require('mathjax-full/js/adaptors/liteAdaptor.js');
const {RegisterHTMLHandler} = require('mathjax-full/js/handlers/html.js');
require('mathjax-full/js/input/tex/ams/AmsConfiguration.js');
require('mathjax-full/js/input/tex/newcommand/NewcommandConfiguration.js');
require('mathjax-full/js/input/tex/boldsymbol/BoldsymbolConfiguration.js');
const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);
const doc = mathjax.document('', {InputJax:new TeX({packages:['base','ams','newcommand','boldsymbol'], maxBuffer:16000, maxMacros:500}), OutputJax:new SVG({fontCache:'none'})});
let input='';
process.stdin.setEncoding('utf8');
process.stdin.on('data', d => {input+=d;if(input.length>1000000)process.exit(1)});
process.stdin.on('end', () => {
 try {
 const formulas = JSON.parse(input);
 const result = formulas.map(f => {
  try {
   const node = doc.convert(f.tex, {display:f.display, em:14, ex:7, containerWidth:1000});
   const svg = adaptor.firstChild(node);
   const serialized = adaptor.outerHTML(svg);
   if (serialized.includes('data-mml-node="merror"'))return {error:'La expresión contiene sintaxis no compatible'};
   const view = adaptor.getAttribute(svg,'viewBox').split(/\s+/).map(Number);
   return {svg:serialized, width:view[2]/1000*14, height:view[3]/1000*14};
  }catch(e){return {error:'No se pudo componer esta expresión'}}
 });
 process.stdout.write(JSON.stringify(result));
 }catch(e){process.exitCode=1;}
});
