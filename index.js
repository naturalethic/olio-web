// Generated by LiveScript 1.4.0
(function(){
  var axios, inflection, reactive, olio, bindings, out$ = typeof exports != 'undefined' && exports || this;
  import$(window, require('prelude-ls'));
  window.$ = window.jQuery = require('semantic-ui-css/node_modules/jquery/dist/jquery');
  require('semantic-ui-css/semantic');
  axios = require('axios');
  inflection = require('inflection');
  reactive = require('reactive');
  if (console.log.apply) {
    each(function(key){
      return window[key] = function(){
        return console[key].apply(console, arguments);
      };
    })(
    ['log', 'info', 'warn', 'error']);
  } else {
    each(function(key){
      return window[key] = console[key];
    })(
    ['log', 'info', 'warn', 'error']);
  }
  out$.olio = olio = {};
  olio.api = {
    _add: function(module, name){
      var ref$, func;
      name == null && (name = module);
      (ref$ = olio.api)[module] == null && (ref$[module] = {});
      func = function(data){
        return axios({
          url: (name && "/" + module + "/" + name) || "/" + module,
          method: 'put',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          data: data
        });
      };
      if (name === module || name === inflection.pluralize(module)) {
        return olio.api[name] = func;
      } else {
        return olio.api[module][name] = func;
      }
    }
  };
  olio.state = {};
  olio.go = function(route, state){
    return history.pushState(state, '', route);
  };
  window.onpopstate = function(it){
    return info('STATE', it);
  };
  bindings = {
    route: function(el, val){
      if (val !== olio.state.route) {
        return $(el).hide();
      }
    }
  };
  $(function(){
    var name, ref$, template, results$ = [];
    olio.state.route = location.pathname;
    history.replaceState(null, '', location.pathname);
    for (name in ref$ = olio.template) {
      template = ref$[name];
      results$.push(each(fn$)(
      $("." + name + ":not(.olio-initialized)")));
    }
    return results$;
    function fn$(el){
      var attrs, view;
      attrs = '';
      each(function(it){
        if (it.name === 'class') {
          it.value += ' olio-initialized';
        }
        it.value = it.value.replace(/"/g, "'");
        return attrs += " " + it.name + "=\"" + it.value + "\"";
      })(
      el.attributes);
      view = reactive("<div" + attrs + ">" + template + "</div>", olio.state, {
        bindings: bindings
      });
      return $(el).replaceWith(view.el);
    }
  });
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
