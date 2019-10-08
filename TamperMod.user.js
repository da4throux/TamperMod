// ==UserScript==
// @name         TamperMod
// @namespace    http://tampermonkey.net/
// @version      0.3.1
// @description  Help automate some dynamic gesture when using the Mod Duo X
// @author       da4throux
// @match        http://192.168.51.1/*
// @grant_not        GM_xmlhttpRequest //should not be needed anymore
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_getResourceText
// @grant        GM_addStyle
// @grant        unsafeWindow
// @icon         http://192.168.51.1/img/icons/36/mod.png
// @run-at       document-idle
// @resource     MaterialIcons https://fonts.googleapis.com/icon?family=Material+Icons

//*** n cannot be the action to add a new knob, and remove an existing instrument...
//*** I have a poor mix up of objects and array on which I rely on positions... I have to get rid of the latter: continuo, sections, ...
//*** what resistance to a modification of continuo, section, while it's alternating
//*** need to add continuos.mode: alternate, focus on section, fade to New level, pause

const MaterialIcons = GM_getResourceText("MaterialIcons");
GM_addStyle (MaterialIcons);
// https://material.io/resources/icons/?style=baseline
// <i class="material-icons">aspect_ratio</i>
const icons = {
    a : {
        name: 'arrow',
        material: 'call_made'
    },
    c : {
        name: 'circle',
        material: 'fiber_manual_record'
    },
    e : {
        name: 'eye',
        material: 'visibility'
    },
    h : {
        name: 'heart',
        material: 'favorite'
    },
    m : {
        name: 'mobile',
        material: 'stay_primary_portrait'
    },
    s : {
        name: 'star',
        material: 'grade'
    },
    t : {
        name: 'thumb',
        material: 'thumb_up'
    },
    v : { //could be a toggle - or should the icon be greyed
        name: 'volume Off',
        material: 'volume_off'
    }
};
var continuosAction = [];
var continuos = {};
for (const key of Object.keys(icons)) {
    continuos[key.toUpperCase().charCodeAt(0)] = {};
    continuos[key.toUpperCase().charCodeAt(0)].name = icons[key].name;
    continuos[key.toUpperCase().charCodeAt(0)].material = icons[key].material
    continuos[key.toUpperCase().charCodeAt(0)].action = key.toUpperCase().charCodeAt(0);
    continuos[key.toUpperCase().charCodeAt(0)].type = 'continuo';
    continuos[key.toUpperCase().charCodeAt(0)].icon = key;
    continuos[key.toUpperCase().charCodeAt(0)].keyboard = key;
    continuosAction.push(key.toUpperCase().charCodeAt(0));
}

const colors = {
    b : {
        name: 'blue'
    },
    g : {
        name: 'green'
    },
    o : {
        name: 'orange'
    },
    p : {
        name: 'purple'
    },
    r : {
        name: 'red'
    },
    w : {
        name: 'white',
    },
    y : {
        name: 'yellow'
    }
};
var sectionsAction = [], sections = {};
for (const key of Object.keys(colors)) {
    sections[key.toUpperCase().charCodeAt(0)] = {};
    sections[key.toUpperCase().charCodeAt(0)].action = key.toUpperCase().charCodeAt(0);
    sections[key.toUpperCase().charCodeAt(0)].color = colors[key].color ? colors[key].color : colors[key].name
    sections[key.toUpperCase().charCodeAt(0)].name = colors[key].name;
    sections[key.toUpperCase().charCodeAt(0)].type = 'section';
    sections[key.toUpperCase().charCodeAt(0)].keyboard = key;
    sectionsAction.push(key.toUpperCase().charCodeAt(0));
}
// impossible to use a knob the regular way through the web interface
// 32: stop all actions
// assume everything is a multiple of 4 bars at least (i.e. 1, 2 or 4 bars loop)

// ==/UserScript==
// Todo:

// fadeout does not seem to work in mode fade
// might be an issue if the target is the actual value
// the interruption to switch to another effect on the same knob does not seem to work
// fade -Enter- does not seem to land exactly on 0 when starting from -40dB

//  - use the first line with the pedalboardname, to show: list of commands, and their status (running / paused / nothing)
//  ? do I really need to distinguish fade out / in ? isn't it just going to target ?
//  - store the setInterval Id in an external array
//  - define default value for a fadeOut object, so that not all needs to be define
//  - the maximal period should be linked to the BPM (2 times four bars for example)
//  - optimize the keystroke handling
//  ? Why the background-position shift of the knob is not the size of the png
//  ? Do all the gif have the same size (i.e. the same amount of possible steps)
//  - possibility to have a pause of all actions
//  - possibility to store a configuration
//  - do a cross over of the two Gain, one way and the other
//  - how much of the information can I get automatically ?
//  - what kind of configuration to preserve flexibility ?
//  - how to store my configuration for a specific pedalboard (preset elements): JSON / objects
//  - how to display the current configuration ?
//  - GUI to configure
//  ? Can I distinguish one Gain and the other ?
//    . I think one is always the instance /Gain, et l'autre Gain1 (in the pedalboard backup the adressing.json seems to suggest that)
//    . document.querySelectorAll('[mod-instance="/graph/Gain"]')
//  - could I use Midi to controle the script
//  - Could I modify a parameter which is not displayed on the screen ?
//    . for each pedal, the setting box is hidden but present in the Dom
//    ? could I modify directly the value when the box exists ? document.querySelector('[mod-instance="/graph/Gain"][class="mod-settings"]').querySelector('[mod-role="input-control-value"]')
//  ? It's cumbersome to set it up... It is cumbersome to set the buttons links for the pedalboard also... This actually might be simpler since it's all graphic


// Effects I'm interested in
//  - Fade-in or out: setup to reach a certain level (potentially chain 2 gain volume pedal to reach 0) in a certain time, linear, or with variation (making come backs sometimes)
//  - launch several effects in parallel
//  - stable effect but some of its parameter moving around two limits, in a given shape, with a given period (good be happening to a loop)
//  - Crossfade between two gains: time span of the cross-over, shape, take in account the bpm, show where we are in the cross-over (+ countdown), a bit of wavin' (here the next, put in down, and then growing), Could be more than 2, is the target for the new = starting point of the old
//    . coordinate effects between each other (not key as I can launch them in parallel)

// Setting an Effect:
//  - press the type of effect, display the different parameter (click on the pedal, click on the available parameter if several, confirm / support available, display default value, possibility to change, enter key concerned

// What is different between:
//  - the switchbox knob
//  - a pedal small knob: 0-> 3840px, 3840px/65=60px
//  - the big Gain pedal knob: 0-> 6272px/65=
//  - the small gain pedal knob
//  - All: class="mod-knob-image mod-port", symbol = their function name that will be added to instance to build the mod-port,
//  - In resources / knobs, all knobs have 65 steps, except for http://192.168.51.1/resources/knobs/knob.png?uri=http%3A//guitarix.sourceforge.net/plugins/gx_cabinet%23CABINET&v=1_3_28_20


// Features:
//   - effect: fade in or out on Gain type knob
//   - one key: start / pause the effect

function log (message, level) {
    //10 = Debug, 20 = Info, 40 = Error // https://docs.python.org/2.4/lib/module-logging.html
    level = level || 10;
    if (typeof level == 'string' && level == logFocus || level >= logLevel) {
        console.log (typeof message == 'string' ? 'TamperMod: ' + message : message);
    }
}

function triggerMouseEvent (node, eventType) {
    var clickEvent = document.createEvent ('MouseEvents');
    clickEvent.initEvent (eventType, true, true);
    node.dispatchEvent (clickEvent);
}

function triggerEvent(target, type){
    "use strict";
    var event = document.createEvent('HTMLEvents');
    event.initEvent(type, true, true);
    target.dispatchEvent(event);
}

function simulateMouseEvent(target, type, x, y) {
    //https://stackoverflow.com/questions/9749910/programmatically-triggering-mouse-move-event-in-javascript
    var rect = target.getBoundingClientRect();
    log (typeof unsafeWindow);
    log (unsafeWindow);
    var event = new MouseEvent(type, {
        'view': unsafeWindow,
        'bubbles': true,
        'cancelable': true,
        'clientX': x,
        'clientY': y,
        // you can pass any other needed properties here
    });
    target.dispatchEvent(event);
};

const timeStep = 0.2; // minimum step for each action (every .2s I would change the volume knob)
const continuoStep = 2000;
const maxPeriod = 10000; //any action taking more than a second should be reduce to this xx ms - I'm thinking of turning the knob for a fadeOut
const logLevel = 0; const logFocus = 'focus';
var page_title, page_title_original, x = 0, y = 0;
var config_default = {};
var config = {},
    volumes, volumes_families = {}; // keep track of buttons involved in the orchestra (continuos / sections) - before I was thinking of actions, this reverse the approach
// I need to build this from configuration:
// document.querySelector('[mod-instance="/graph/Gain_1"][class="mod-pedal ui-draggable"]').querySelector('[mod-port="/graph/Gain_1/Gain"]')
// when browsing above a pedal, get all its potential control:
//  - document.querySelector('[mod-instance="/graph/mono_8"]').querySelectorAll('[mod-port]').forEach(function(node){console.log(node.getAttribute('mod-port'));})
var actions = []; //need to track for eacth instance/symbol the current action if any
var active_actions = {}; //hash by port of ID of current effect if any
var styles = {
    'fade-out': "crimson",
    'fade-in' : "blue",
    'stable'  : "lime",
};
var fade_colors = {
    '-1': 'blue',
    '1': 'crimson'
};
var default_filter = 'drop-shadow(20px 6px 20px Fuchsia)';

function knob_style (remaining_steps, type) { //number of steps away from target, fade_in/out...
    var _style = 'drop-shadow(';
    _style += Math.round(remaining_steps / 64 * 30) + 'px 6px ' + Math.round(remaining_steps / 64 * 30) + 'px ' + styles[type] + ')';
    return _style;
}

function port_style (remaining_steps, direction) { //number of steps away from target, fade_in/out...
    var _style = 'drop-shadow(';
    _style += Math.round(remaining_steps / 64 * 30) + 'px 6px ' + Math.round(remaining_steps / 64 * 30) + 'px ' + fade_colors[direction] + ')';
    return _style;
}

volumes_families.Gain = {
    symbol: 'Gain',
    description: 'simple V3 pedal, v3 knob',
    type: 'knob',
    steps: 65,
    size: 98,
    volumes: {
        low: 0,
        mid: 24,
        high: 32,
        size: 98
    }
};

//*** I kind of set a limit to 10 loops (0 to 9) - ok for the time being I guess
volumes = {
    0: {
        instance: "/graph/Gain_1",
        symbol: "Gain",
        description: "V3 pedal TOP looper",
    },
    1: {
        instance: "/graph/Gain",
        symbol: "Gain",
        description: "V3 pedal BOTTOM looper"
    },
    2: {
        instance: "/graph/Gain_2",
        symbol: "Gain",
        description: "V3 direct"
    },
};

var instruments = {}, instrumentsAction = [];
for (var key of Object.keys(volumes)) {
    instruments[key.toUpperCase().charCodeAt(0)] = {};
    instruments[key.toUpperCase().charCodeAt(0)].instance = volumes[key].instance;
    instruments[key.toUpperCase().charCodeAt(0)].symbol = volumes[key].symbol;
    instruments[key.toUpperCase().charCodeAt(0)].description = volumes[key].description;
    instruments[key.toUpperCase().charCodeAt(0)].key = key.toUpperCase().charCodeAt(0);
    instruments[key.toUpperCase().charCodeAt(0)].type = 'instrument';
    instruments[key.toUpperCase().charCodeAt(0)].volume = key;
    instruments[key.toUpperCase().charCodeAt(0)].name = volumes[key].description;
    instruments[key.toUpperCase().charCodeAt(0)].keyboard = key;
    instruments[key.toUpperCase().charCodeAt(0)].section = sections[sectionsAction[instrumentsAction.length]];
    instruments[key.toUpperCase().charCodeAt(0)].continuo = continuos[continuosAction[instrumentsAction.length]];
    instruments[key.toUpperCase().charCodeAt(0)].sectionRank = 0;
    instrumentsAction.push(instruments[key.toUpperCase().charCodeAt(0)]);
}

//continuos = [[0, 1]]; // instruments from section 0 & 1 are alternating in one continuo

//if (!GM_getValue('config')) {
    config_default.actions = {};
    config_default.actions.keydown13x = [{
        type: 'fade',
        description: 'Enter: fade to target -> 0dB on 2 bars loop volume',
        instance: "/graph/Gain",
        symbol: 'Gain',
        target: 32, // for a knob that goes in 64 steps: 0 minimum, 64 maximum
        timespan: 30, //0 for instantaneous (in 10 seconds the sound will be at minimal level)
        steps: 65, //? 65 should be defaut value if not indicated, most knobs have 65 steps to move from min to max -> I should find it my own though
        size: 98, //pixel size of the knob to calculate what is the current step
    }];
    config_default.actions.keydown32x = [{ //space bar
        type: 'fade',
        description: 'space: fade-out on 2 bars loop volume set on the right',
        instance: "/graph/Gain",
        symbol: 'Gain',
        target: 10, // for a knob that goes in 64 steps: 0 minimum, 64 maximum
        timespan: 30, //0 for instantaneous (in 10 seconds the sound will be at minimal level)
        steps: 65, //? 65 should be defaut value if not indicated, most knobs have 65 steps to move from min to max -> I should find it my own though
        size: 98, //pixel size of the knob to calculate what is the current step
    }];
    config_default.actions.keydown65x = [{ //a (as keydown it's 65, but as keypress it's 97) // let's make it an array of functions to allow overload
        type: 'fade',
        description: 'a: fade-out on 4 bars loop volume set on the right',
        instance: "/graph/Gain_1",
        symbol: 'Gain',
        target: 10, // for a knob that goes in 64 steps: 0 minimum, 64 maximum
        timespan: 30, //0 for instantaneous (in 10 seconds the sound will be at minimal level)
        steps: 65, //? 65 should be defaut value if not indicated, most knobs have 65 steps to move from min to max -> I should find it my own though
        size: 98, //pixel size of the knob to calculate what is the current step
    }];
    config_default.actions.keydown66x = [{ //a (as keydown it's 65, but as keypress it's 97) // let's make it an array of functions to allow overload
        type: 'fade',
        description: 'b: fade back on 4 bars loop volume set on the right',
        instance: "/graph/Gain_1",
        symbol: 'Gain',
        target: 32, // for a knob that goes in 64 steps: 0 minimum, 64 maximum
        timespan: 30, //0 for instantaneous (in 10 seconds the sound will be at minimal level)
        steps: 65, //? 65 should be defaut value if not indicated, most knobs have 65 steps to move from min to max -> I should find it my own though
        size: 98, //pixel size of the knob to calculate what is the current step
    }];
    config_default.actions.keydown67AndMore = [{
        type: 'inAndOut',
        description: 'c: in&out',
//        instance: "/graph/Gain2x2",
        instance: "/graph/Gain_1",
        symbol: 'Gain',
        low: 0,
        mid: 24,
        high: 32,
        steps: 65,
        size: 98
    }];
    config_default = JSON.stringify(config_default);
    GM_setValue('config', config_default);
log ('GM_setValue done', config_default, typeof GM_setValue.then); //
//}

function investigationOfModPorts() { //look for all possible value of mod-port
    //many many different names: no logic I can see me exploit
    var el, attr, i, allGain = [], allGains = [], arr = [], els = document.body.getElementsByTagName('*'); //get all tags in body
    log(els.length);
    for (i = 0; i < els.length; i++) {
        el = els[i];
        attr = el.getAttribute('mod-port-symbol');
        if (attr && arr.indexOf(attr) == -1) {
            arr.push(attr);
        }
        if (attr == 'Gain') {
            allGain.push(el.getAttribute('mod-port')); //confirms that Gain is only used for the v3 pedal
            allGains.push(el);
        }
    }
    log(arr);
    log(allGain);
    log(allGains);
    return true;
}

function createIconNode(material, color) {
    var icon = document.createElement('i');
    icon.className = "material-icons";
    icon.innerText = material;
    icon.setAttribute('style', "font-family:'Material Icons' !important; color:" + color);
    return icon;
}

function appendIconNode(material, color, node) {
    var icon = createIconNode(material, color);
    if (node) {
        node.appendChild(icon);
    }
    return icon;
}

function createTextNode(text, color, size) {
    var textNode = document.createElement('span');
    textNode.innerText = text;
    if (color) {
        textNode.style.color = color;
    }
    if (size){
        textNode.style.fontSize = size;
    }
    return textNode;
}

function appendTextNode(node, text, color, size) {
    var textNode = createTextNode (text, color || 'green', size || 'x-large');
    textNode.style.fontWeight = 'bolder';
    textNode.style.textAlign = 'center';
    node.appendChild(textNode);
    return true;
}

function updateInstrumentsLabel() {
    var selector;
    for (let inst of Object.values(instruments)) {
        selector = '[mod-instance="' + inst.instance + '"][class="mod-pedal ui-draggable"]';
        inst.anchor = document.querySelector(selector).querySelector('[class="mod-drag-handle"]');
        inst.textNode = document.querySelector(selector).querySelector('[class="mod-plugin-brand"]').children[0]; //h1
        inst.textNode.innerHTML = '';
        appendTextNode(inst.textNode, inst.keyboard, 'white');
        appendIconNode(inst.continuo.material, inst.section.color, inst.textNode);
        appendTextNode(inst.textNode, inst.continuo.keyboard + inst.section.keyboard, 'white');
    }
}

function buildConfigAndActions(){
    var i;
//    investigationOfModPorts();
    page_title_original = document.getElementById('pedalboard-info').children[0].innerHTML;
    page_title = document.getElementById('pedalboard-info').children[0];
    page_title.style.textTransform = 'none';
    updateInstrumentsLabel();
    config = JSON.parse(GM_getValue('config'));
    appendIconNode('face', 'pink');
    appendIconNode('call_made', 'purple');
    for (let [actionKeyCode, key_actions] of Object.entries(config.actions)) {
        actions[actionKeyCode]=[];
        key_actions.forEach((key_action, index) => {
          if (document.querySelector('[mod-instance="' + key_action.instance + '"][class="mod-pedal ui-draggable"]')) {
            actions[actionKeyCode][index]={};
            switch(key_action.type) {
                case 'fade':
                case 'fade-out':
                case 'inAndOut':
                    actions[actionKeyCode][index].port = document.querySelector('[mod-instance="' + key_action.instance + '"][class="mod-pedal ui-draggable"]').querySelector('[class="mod-knob-image mod-port"]');
                    actions[actionKeyCode][index].port.title += actions[actionKeyCode][index].port.title ? '\n' + key_action.description : key_action.description;
                    actions[actionKeyCode][index].port.style.filter = default_filter;
                    actions[actionKeyCode][index].portName = key_action.instance + '/' + key_action.symbol;
                    actions[actionKeyCode][index].portSize = parseInt(window.getComputedStyle(actions[actionKeyCode][index].port).backgroundSize.match(/\d+/)[0]);
                    actions[actionKeyCode][index].port.style.color = 'lime';
                    actions[actionKeyCode][index].port.style.font = 'bold 50px arial,serif';
                    actions[actionKeyCode][index].title = actions[actionKeyCode][index].port;
                    break;
                default:
                    log ('buildActions:', key_action.type,'not handled');
            }
          }
        })
    }
    log ('buildConfigAndAction loaded');
    setInterval (goThroughContinuos, continuoStep);
}

function moveMouse(port, stepsToTarget) {
    ["mouseover", "mousedown"].forEach(function(eventType) { triggerMouseEvent(port, eventType);});
    simulateMouseEvent(port, 'mousemove', x , y + 2 * stepsToTarget);
    ["mouseup", "click"].forEach(function(eventType) { triggerMouseEvent(port, eventType);});
}

function getContinuoSize(continuo) { //number of different sections in the continuo
    continuo.size = 0;
    var trackedSection = [];
    for (let instrument of Object.values(instruments)) {
        if (instrument.continuo.name == continuo.name && trackedSection.indexOf(instrument.section.name) == -1) {
            trackedSection.push(instrument.section.name);
            continuo.size++;
        }
    }
    return continuo.size;
}

function modulo(a, b) {
    var modulo;
    modulo = ((a % b) + b) % b;
    return modulo;
}

function goThroughContinuos() {
    var bpm, continuo, continuoPeriod, currentSection, currentVolume, instrument, k, period, periodShift, port, rank, stepsToTarget, targetVolume, timePosition, volumes;
    bpm = parseFloat(document.getElementById('mod-transport-icon').firstElementChild.innerHTML.match(/\d+(\.\d+)?/g, '')[0]);
    period = 60 * 4 / bpm * 4; // 4 black notes, 4 times -> second length
    periodShift = 1 / continuosAction.length; //so that continuos have an equal repartition on a period //*** a bit unsure about that though, not all are used...
    // shouldn t timePosition be based on the continuo, its size, and its reference start point (to take in account pause, and change)
    // some part of rank should be based on continuo.size, and its position in the period should be based on sectionrank (and this should be section.rank)
    for (let instrument of Object.values(instruments)) {
        continuo = instrument.continuo;
        timePosition = (( Date.now() - (continuo.startTime || 0 )) / 1000 / period) % (4 * continuo.size);
        log (instrument.name + ' = ' + continuo.name + '-' + continuo.size + '.' + instrument.section.name + '-' + instrument.sectionRank + ', mode: ' + (continuo.mode || 'not set') + ' phase: ' + timePosition % (4 * rank));
        if (!continuo.size) { getContinuoSize(continuo); }
        if (continuo.mode != 'pause' && continuo.size > 0) {
            volumes = instrument.volumes || volumes_families[instrument.symbol].volumes;
            port = document.querySelector('[mod-instance="' + instrument.instance + '"][class="mod-pedal ui-draggable"]').querySelector('[class="mod-knob-image mod-port"]');
            currentVolume = Math.round(parseInt(port.style.backgroundPositionX) / -1 / volumes.size);
            log('timePosition: ' + timePosition);
            if (continuo.size == 1) {
                targetVolume = currentVolume < volumes.mid ? volumes.mid : volumes.high; //else it would be a too extreme change
            } else {
                continuoPeriod = 4 * continuo.size; //8 = 4 * 2, 1 if there is two sections in the continuo
                rank = 4 * instrument.sectionRank; //in that case will be 0 & 4
                switch (true) {
                    case ((timePosition > rank) && (timePosition < (rank + 3))):
                        targetVolume = currentVolume < volumes.mid ? volumes.mid : volumes.high;
                        break;
                    case ((timePosition > (rank + 3)) && (timePosition <= rank + 4)):
                        targetVolume = volumes.mid;
                        break;
                    case (timePosition > modulo(rank - 2, continuoPeriod) && timePosition <= modulo(rank - 1, continuoPeriod)):
                        targetVolume = volumes.mid;
                        break;
                    case (timePosition > modulo(rank - 1, continuoPeriod) && timePosition <= (rank || continuoPeriod)):
                        targetVolume = currentVolume < volumes.mid ? volumes.mid : volumes.high;
                        break;
                    default:
                        targetVolume = currentVolume > volumes.mid ? volumes.mid : volumes.low;
                        break;
                }
            }
            stepsToTarget = Math.round(continuoStep * (currentVolume - targetVolume) / (1 - timePosition % 1) / period / 1000);
            log('gTC: ' + instrument.keyboard + ': ' + rank + '/' + timePosition + ' : ' + currentVolume + ' -> ' + targetVolume + ' : ' + stepsToTarget + ' y=' + y);
            moveMouse (port, stepsToTarget);
        }
    }
}

function highLowGetCurrent(context) {
    //send the context necessary to calculate the next level based on the current time
    var bpm, level, period, timePosition;
    bpm = parseFloat(document.getElementById('mod-transport-icon').firstElementChild.innerHTML.match(/\d+(\.\d+)?/g, '')[0]);
    period = 60 * 4 / bpm * 4;
    timePosition = ((Date.now() - context.startTime) / 1000 / period) % 6;
    switch (Math.floor(timePosition)) {
        case 0:
            level = context.low + (context.mid - context.low) * (timePosition % 1);
            break;
        case 1:
            level = context.mid + (context.high - context.mid) * (timePosition % 1);
            break;
        case 2:
        case 3:
            level = context.high;
            break;
        case 4:
            level = context.high - (context.high - context.mid) * (timePosition % 1);
            break;
        case 5:
            level = context.mid - (context.mid - context.low) * (timePosition % 1);
            break;
        default:
            log('highLowGetCurrent not working: ' + Math.floor(timePosition));
    }
    return level;
}

function updateTitle(clicked) {
    page_title.innerHTML = '';
    if (clicked.instrument != null) {
        page_title.appendChild(createTextNode(clicked.instrument.name + ' instrument ' + clicked.instrument.keyboard + ' - press n to remove, '));
    }
    if (clicked.newInstrument != null) {
        page_title.appendChild(createTextNode(clicked.newInstrument.symbol + ' ' + clicked.newInstrument.instance + ' press n to create, '));
    }
    if (clicked.continuo != null) {
        log('continuo found');
        page_title.appendChild(createIconNode(clicked.continuo.material));
        page_title.appendChild(createTextNode(' continuo, '));
    }
    if (clicked.section != null) {
        page_title.appendChild(createTextNode(clicked.section.name + ' section, ', clicked.section.color));
    }
    if (clicked.text != null) {
        page_title.appendChild(createTextNode(clicked.text));
        clicked.text = '';
    }
    return true;
}

function isSectionEmpty(section, continuo) {
    var empty = true;
    for (let inst of Object.values(instruments)) {
        if (inst.section.name == section.name && inst.continuo.name == continuo.name) {
            empty = false;
        }
    }
    return empty;
}

function updateInstrumentAfterSectionChange(instrument, newSection, newContinuo) {
    var aloneInNewSection = true, emptyOldSection, oldContinuo, oldSection, oldSectionRank, otherSections = [], maxRank = 0;
    log('instrument');
    log(instrument);
    oldSection = instrument.section;
    oldContinuo = instrument.continuo;
    oldSectionRank = instrument.sectionRank;
    instrument.section = newSection;
    instrument.continuo = newContinuo;
    emptyOldSection = isSectionEmpty(oldSection, oldContinuo);
    if (emptyOldSection) {
        oldContinuo.size--;
    }
    for (let inst of Object.values(instruments)) {
        if (inst.name != instrument.name) {
            if (inst.continuo.name == oldContinuo.name && emptyOldSection && inst.sectionRank > oldSectionRank) { // if oldSection disappear
                inst.sectionRank--; //
            }
            if (inst.continuo.name == newContinuo.name) { //is newSection already populated
                if (inst.section.name == newSection.name) {
                    aloneInNewSection = false;
                    instrument.sectionRank = inst.sectionRank;
                } else { // else its rank would be the highest + 1
                    if (otherSections.indexOf(inst.section.name) < 0) {
                        otherSections.push(inst.section.name);
                        maxRank = Math.max(maxRank, inst.sectionRank);
                    }
                }
            }
        }
    }
    if (aloneInNewSection) {
        instrument.sectionRank = maxRank + 1;
        newContinuo.size++;
    }
}

function checkActionable(clicked) {
    if (clicked.section != null && clicked.instrument != null) { //changing an instrument section
        if (clicked.section.name != clicked.instrument.section.name) {
            updateInstrumentAfterSectionChange(clicked.instrument, clicked.section, clicked.instrument.continuo);
            log('instrument sectionRank is: ' + clicked.instrument.sectionRank + ' in section ' + clicked.section.name);
            clicked.text = clicked.instrument.name +' instrument is now in section ' + clicked.instrument.section.name + ' of continuo ' + clicked.instrument.continuo.name;
            updateInstrumentsLabel();
            delete clicked.instrument;
            delete clicked.section;
        } else {
            clicked.text = clicked.instrument.name + ' instrument already in section ' + clicked.section.name;
            delete clicked.instrument;
            delete clicked.section;
        }
    }
    if (clicked.continuo != null && clicked.instrument != null) { //changing an instrument continuo
        if (clicked.continuo.name != clicked.instrument.continuo.name) {
            clicked.instrument.continuo = clicked.continuo;
            updateInstrumentAfterSectionChange(clicked.instrument, clicked.instrument.section, clicked.continuo);
            clicked.text = clicked.instrument.name +' instrument is now in section ' + clicked.instrument.section.name + ' of continuo ' + clicked.instrument.continuo.name;
            updateInstrumentsLabel();
            delete clicked.instrument;
            delete clicked.continuo;
        } else {
            clicked.text = clicked.instrument.name + ' instrument already in continuo ' + clicked.continuo.name;
            delete clicked.instrument;
            delete clicked.continuo;
        }
    }
    return true;
}

(function() {
    'use strict';
    log('TamperMod is waiting to load its configuration');
    var clicked, target;
    clicked = {};
    var si_id = setInterval(function() { //only loadConfiguration once the pedalboard is fully loaded
        if (document.getElementsByClassName('screen-loading blocker')[0].style.display == 'none') {
            buildConfigAndActions();
            clearInterval(si_id);
        }
    }, 500);
    document.addEventListener('mouseup', function (e) {
        x = e.pageX;
        y = e.pageY;
        target = e.target;
        if (e.button == 1) { //middle click - the only one I can overload without disturbing anyone
            target = target.getAttribute('mod-port');
            if (clicked && !target) {
                clicked = {};
                page_title.innerHTML = page_title_original;
                page_title.style.color = "#999";
            }
            if(target) {
                log('you clicked on: ' + target);
                clicked.newInstrument = {};
                clicked.newInstrument.instance = target.slice(0, target.lastIndexOf('/'));
                clicked.newInstrument.symbol = target.slice(target.lastIndexOf('/') + 1);
                clicked.action = 'setup instrument';
            }
        }
        updateTitle(clicked);
    }, false);
    // https://stackoverflow.com/questions/2601097/how-to-get-the-mouse-position-without-events-without-moving-the-mouse
    //press 'a' for toggling the gain on/off
    document.addEventListener('keydown', function (keyEvent) {
        var conf, fade_direction, id, knob, period, port, instNumber;
        log (keyEvent.keyCode + ' key was pressed.');
        // https://unicode-table.com/en/#control-character
        // https://unicodelookup.com/
        if (instruments[keyEvent.keyCode]) {
            clicked.instrument = instruments[keyEvent.keyCode];
        }
        if (sectionsAction.indexOf(keyEvent.keyCode) > -1) {
            clicked.section = sections[keyEvent.keyCode];
        }
        if (continuosAction.indexOf(keyEvent.keyCode) > -1) {
            clicked.continuo = continuos[keyEvent.keyCode];
        }
        if (actions['keydown'+keyEvent.keyCode]) {
            actions['keydown'+keyEvent.keyCode].forEach(function (action, index) {
                conf = config.actions['keydown'+keyEvent.keyCode][index];
                log(' Finally doing an action from the loaded configuration:');
                log(conf);
                log(action);
                switch(conf.type) {
                    case 'inAndOut':
                        port = action.port;
                        conf.startTime = Date.now();
                        id = active_actions[action.portName].id = setInterval(function(){
                            var countdown = action.port;
                            var current_level = Math.round(parseInt(port.style.backgroundPositionX) / -98);
                            var target_level = Math.round(highLowGetCurrent(conf));
                            var effect_type = conf.type;
                            if (target_level != current_level) {
                                log(current_level + ' -> ' + target_level);
                                var steps_to_target = current_level - target_level;
                                ["mouseover", "mousedown"].forEach(function(eventType) { triggerMouseEvent(port, eventType);});
                                simulateMouseEvent(port, 'mousemove', x , y + 2 * steps_to_target);
                                ["mouseup", "click"].forEach(function(eventType) { triggerMouseEvent(port, eventType);});
                                //countdown.innerText = (steps_to_target).toFixed(1) + 'steps';
                            }
                        }, period);
                        break;
                    case 'fade':
                    case 'fade-out':
                        (function () { //? want to create a scope as I'm itirating through all actions, but is it really necessary ?
                            //!!! need to push the id to a separate array, that would be externally cleaned if there is concurrency, and internally clean if everything workout right
                            port = action.port;
                            if (active_actions[action.portName]) {
                                if (active_actions[action.portName].trigger == 'keydown' + keyEvent.keyCode) {
                                    active_actions[action.portName].pause = !active_actions[action.portName].pause;
                                    //toggle pause for an exting running/active action for that button
                                } else {
                                    var action_to_replace = active_actions[action.portName].id;
                                    clearInterval(action_to_replace);
                                    active_actions[action.portName] = null;
                                    //if there's already a different action running for that button, then kill it
                                }
                            }
                            if (!active_actions[action.portName]) {
                                period = Math.min(conf.timespan * 1000 / Math.abs(parseInt(port.style.backgroundPositionX) / -98 - conf.target + 0.1), maxPeriod);
                                fade_direction = parseInt(port.style.backgroundPositionX) / -98 > conf.target ? 1 : -1; // fade-out = 1, fade-in = -1
                                log('period: ' + period);
                                log('port to fade-out * ' + fade_direction + ' to ' + conf.target);
                                log(port);
                                active_actions[action.portName] = {
                                    trigger: 'keydown' + keyEvent.keyCode
                                };
                                id = active_actions[action.portName].id = setInterval(function(){
                                    if (!active_actions[action.portName].pause) {
                                        var effect_type = conf.type;
                                        var steps_to_target = Math.abs(parseInt(port.style.backgroundPositionX) / -98 - conf.target);
                                        var countdown = action.port;
                                        ["mouseover", "mousedown"].forEach(function(eventType) { triggerMouseEvent(port, eventType);});
                                        simulateMouseEvent(port, 'mousemove', x , y + 2 * fade_direction);
                                        ["mouseup", "click"].forEach(function(eventType) { triggerMouseEvent(port, eventType);});
                                        log ('gain: ' + (parseInt(port.style.backgroundPositionX) + 3136) / 3136 * -40 + 'dB');
                                        log('calling:' + port_style(steps_to_target, fade_direction));
                                        port.style.filter = port_style(steps_to_target, fade_direction);
                                        countdown.innerText = (steps_to_target * period / 1000).toFixed(1) + 's';
                                    }
                                    if (steps_to_target <= 1.5) {
                                        active_actions[action.portName] = null;
                                        clearInterval(id);
                                        log(effect_type,'finished');
                                        countdown.innerText = '';
                                        port.style.filter = default_filter;
                                    } // !!! 'reached the timeout, or request overide' ?
                                }, period);
                            }
                        })();
                        break;
                    default:
                        log('unknown action type:',conf.type);
                }
            });
        }
        if (keyEvent.keyCode === 666) {
            log (' -> volume up');
            document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]')[0].getElementsByClassName('mod-footswitch')[0].click();
            knob = document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]')[0].getElementsByClassName('mod-knob-image')[0];
            ["mouseover", "mousedown"].forEach(function(eventType) { triggerMouseEvent(knob, eventType);});
            simulateMouseEvent(knob, 'mousemove', x , y + 2);
            ["mouseup", "click"].forEach(function(eventType) { triggerMouseEvent(knob, eventType);});
            log ('Gain: ', (parseInt(knob.style.backgroundPositionX) + 3136) / 3136 * -40, 'dB');
        }
        if (keyEvent.keyCode === 67.1) { //c volume down
            log ('"c" was pressed');
            document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]')[0].getElementsByClassName('mod-footswitch')[0].click();
            knob = document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]')[0].getElementsByClassName('mod-knob-image')[0];
            ["mouseover", "mousedown"].forEach(function(eventType) { triggerMouseEvent(knob, eventType);});
            simulateMouseEvent(knob, 'mousemove', x , y - 2);
            ["mouseup", "click"].forEach(function(eventType) { triggerMouseEvent(knob, eventType);});
            log ('Gain: ', (parseInt(knob.style.backgroundPositionX) + 3136) / 3136 * -40, 'dB');
        }
        if (keyEvent.keyCode === 69) { //e Fail: try directly modifying the value
            log ('d:  modify the Gain numerically in the setting box - does not work if the setting box is hidden');
            knob = document.querySelector('[mod-instance="/graph/Gain"][class="mod-settings"]').querySelector('[mod-role="input-control-value"]');
//            ["mouseover", "mousedown", "focus", "mouseup", "click"].forEach(function(eventType) { triggerMouseEvent(knob, eventType);});
            knob.innerText = "0dB";
            ["focus", "change"].forEach(function(eventType) { triggerEvent(knob, eventType);});
            setTimeout(function() {
                knob.focus();
                knob.innerText = "0dB";
                knob.blur();
            }, 0);
        }
        checkActionable(clicked); //??? why the object is not updated ?!
        updateTitle(clicked);
    });
})();

//
// Notes:
// document.querySelector('[mod-instance="/graph/Gain_1"][class="mod-pedal ui-draggable"]').querySelector('[mod-port="/graph/Gain_1/Gain"]')
// document.getElementsByClassName('mod-knob')[0]
// document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]') -> the 1st 2 are the Gain pedal (but there's 5 on the page...)
// document.querySelectorAll('[mod-instance="/graph/Gain"]') -> get 2 results, but the other pedal is Gain_1
// document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]')[0].getElementsByClassName('mod-footswitch')[0].click() -> 0 or 1 for one pedal or the other
// document.querySelectorAll('[mod-role="input-control-port"]') -> all the knobs (& a bit more)
// document.querySelectorAll('[mod-uri="http%3A//moddevices.com/plugins/mod-devel/Gain"]')[0].getElementsByClassName('mod-knob-image')[0]

// ? Can I put more information on the background pedal itself ?
// document.querySelector('[mod-instance="/graph/Gain_1"][class="mod-pedal ui-draggable"]').querySelector('[class="mod-drag-handle"]')


// ? Do I change the interface (simulate User Interaction), or directly sends the Post Event to the server -> Although  elegant, Post would need to access the cookie, so focusing on mouse simulation interaction for the time being
//   -> 190820 Tried a bit, but could not emulate the "official" post, always rejected
// turning the Knob:
//  - I can turn the knob up or down it seems, but how do I know how much is left to turn
//  - Gain knob image: http://192.168.51.1/resources/knobs/boxy/black.png?uri=http%3A//moddevices.com/plugins/mod-devel/Gain&v=1_0_1_12
//  - Need to know what part of that image is displayed (left: Gain 0, right Gain 100): 8320 x 128: 65 states
//  - when showing at 98px: 8320 * 98 / 128 = 6370, maximum shift is: 6370-98=6272=64 * 98
//  - 0: -3136px, -40dB: 0, +40dB: -6272px (background-position), but it seems to be 98px height. (why isn't linked to 8320... ?) - value change for type of knobs
//  - 2px is the knob increment: on y or x, one direction increase, the other decrease (going in diagonal could either cancel effect or double it)
// I probably have to take in account the position of the mouse before using it - right now I see it at 0,0 when its position should be on the knob... (it's the relative movement change that matter though)
