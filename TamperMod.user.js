// ==UserScript==
// @name         TamperMod
// @namespace    http://tampermonkey.net/
// @version      0.3.4
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

//** increase decrease volume
//*** what is the right maner to handle a pad withouth instrument (a looper without volume)
//** do I need to keep the addition of elements in the interface (it more feels like it's once and for all) -> I could have configurations based on the title of the session
//*** two types of pause: one silent, one just pause all movement to allow interaction with the interface
//*** need to add continuos.mode: alternate, focus on section, fade to New level, pause
//*** keyboard map - how to present the actions (how does it change from one machine to another)
//? reselecting a looper currently deselect it, but it might be more intuitive that it simulate pressing on the button + adding a button to clean the actions (Del)
//? button to save the current setting, and then reload it in an instant
//** n cannot be the action to add a new knob, and remove an existing instrument...
//** Could investigate an auto engagement: as soon as the mouse is touched: disengage, and re-engage with no movement for 2 seconds
//** Could image the mouse as a way to control some type of engagement
//** Could I show more clearly the elements in the same continuo + section

const MaterialIcons = GM_getResourceText("MaterialIcons");
GM_addStyle (MaterialIcons);
// https://material.io/resources/icons/?style=baseline
// <i class="material-icons">aspect_ratio</i>
const icons = { // https://keycode.info/
    a : {
        name: 'arrow',
        material: 'call_made',
        code: 'KeyA'
    },
    c : {
        name: 'circle',
        material: 'fiber_manual_record',
        code: 'KeyC',
    },
    e : {
        name: 'eye',
        material: 'visibility',
        code: 'KeyE'
    },
    h : {
        name: 'heart',
        material: 'favorite',
        code: 'KeyH'
    },
    m : {
        name: 'mobile',
        material: 'stay_primary_portrait',
        code: 'KeyM'
    },
    s : {
        name: 'star',
        material: 'grade',
        code: 'KeyS'
    },
    f : {
        name: 'facebook',
        material: 'thumb_up',
        code: 'KeyF'
    },
    v : { //could be a toggle - or should the icon be greyed
        name: 'volume Off',
        material: 'volume_off',
        code: 'KeyV'
    }
};
var continuosAction = [];
var continuos = {};
for (const key of Object.keys(icons)) {
    let code = icons[key].code;
    continuos[code] = Object.assign({}, icons[key]);
    continuos[code].type = 'continuo';
    continuos[code].keyboard = key;
    continuosAction.push(code);
}

const colors = {
    b : {
        name: 'blue',
        code: 'KeyB'
    },
    g : {
        name: 'green',
        code: 'KeyG'
    },
    o : {
        name: 'orange',
        code: 'KeyO'
    },
    p : {
        name: 'purple',
        code: 'KeyP'
    },
    r : {
        name: 'red',
        code: 'KeyR'
    },
    w : {
        name: 'white',
        code: 'KeyW'
    },
    y : {
        name: 'yellow',
        code: 'KeyY'
    }
};
var sectionsAction = [], sections = {};
for (const key of Object.keys(colors)) {
    let code = colors[key].code;
    sections[code] = Object.assign({}, colors[key]);
    sections[code].color = colors[key].color ? colors[key].color : colors[key].name
    sections[code].type = 'section';
    sections[code].keyboard = key;
    sectionsAction.push(code);
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
    log ('SME - unsafeWindow: ' + typeof unsafeWindow);
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
var bpm, beat;
var page_title, page_title_original, x = 0, y = 0;
var config_default = {};
var config = {},
    volumes, pedals_families = {}, loopers; // keep track of buttons involved in the orchestra (continuos / sections) - before I was thinking of actions, this reverse the approach
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

pedals_families = {
    Gain: {
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
        },
    },
    Alo: {
        clickedStyle: '-71px 0px', //the backgroundPosition when clicked
        symbol: "loop1",
        color: "yellow",
    }
};

//*** I kind of set a limit to 10 loops (0 to 9) - ok for the time being I guess
volumes = {
    0: {
        instance: "/graph/Gain_1",
        symbol: "Gain",
        description: "V3 pedal TOP looper",
        family: "Gain",
        code: "Digit0"
    },
    1: {
        instance: "/graph/Gain",
        symbol: "Gain",
        description: "V3 pedal BOTTOM looper",
        family: "Gain",
        code: "Digit1"
    },
    2: {
        instance: "/graph/Gain_2",
        symbol: "Gain",
        description: "V3 direct",
        family: "Gain",
        code: "Digit2"
    },
    3: {
        instance: "/graph/Gain_3",
        symbol: "Gain",
        description: "raw V3 ",
        family: "Gain",
        code: "Digit3"
    }
};

loopers = {
    0: {
        instance: "/graph/alo_2", //querySelector('[mod-instance="/graph/alo_2"]'),
        symbol: "loop1", //querySelector('[mod-port-symbol="loop1"]'),
        family: "Alo",
        code: "Digit0"
    },
    1: {
        instance: "/graph/alo_1",
        family: "Alo",
        code: "Digit1",
    },
    3: {
        instance: "/graph/alo",
        description: "bar 2 raw looper",
        family: "Alo",
        kind: "raw",
        code: "Digit3"
    },
};


var instruments = {}, instrumentsAction = [];
var pads = {};
//continuos = [[0, 1]]; // instruments from section 0 & 1 are alternating in one continuo

//if (!GM_getValue('config')) {
config_default.actions = {};
var generalActions = {};
generalActions = {
    Space : { //V3 off button toogle
        type: 'action',
        keyboard: 'space',
        description: 'toggle tamperMod engagement (recommended for web page direct interaction)',
        name: 'engagement',
    },
    Period : {
        type: 'action',
        keyboard: '.',
        description: 'toggle the associated loop',
        name: 'loopClick',
    },
    Backquote : {
        type: 'action',
        keyboard: '~', //Alt + ;
        description: 'rotating section for continuo mode', //?
        name: 'rotate',
    },
    Minus : {
        type: 'action',
        keyboard: '-', //between - and _ (sound / no sound) //*** wouldn't it be better to play on the sound level instead ? that way the rythm is always shown
        description: 'one Click - could be starting or stopping a loop immediately',
        name: 'toggle',
    },
    Equal: {
        type: 'action',
        keyboard: '=', //the + sign on top of it: adding a sound
        description: 'double click silence, and will start recording on the 4th beat',
        name: 'record',
    },
    KeyT: {
        type: 'action',
        keyboard: 't', //**** t for transfert but might be better to find a key next
        description: 'transfer raw loop', //there's only one compatible raw loop, so it can be selected automatically
        name: 'transfer',
    },
    Backspace: {
        type: 'action',
        keyboard: 'backspace',
        description: 'silence toggle',
        name: 'pausePlayToggle',
    },
    ArrowUp: {
        type: 'action',
        keyboard: 'up',
        description: 'increase volume',
        name: 'increaseVolume',
    },
    ArrowDown: {
        type: 'action',
        keyboard: 'down',
        description: 'decrease volume',
        name: 'decreaseVolume',
    }
}

config_default = JSON.stringify(config_default);
GM_setValue('config', config_default);
log ('GM_setValue done', config_default, typeof GM_setValue.then); //
//}

function buildConfigAndActions(){
    var i;
    bpm = getBPM(); beat = 60 / bpm * 1000; //beat is in ms
    //    investigationOfModPorts();
    page_title_original = document.getElementById('pedalboard-info').children[0].innerHTML;
    page_title = document.getElementById('pedalboard-info').children[0];
    page_title.style.textTransform = 'none';
    for (let key of Object.keys(volumes)) {
        let instrument = instruments[volumes[key].code] = Object.assign({}, volumes[key]);
        instrument.continuo = continuos[continuosAction[instrumentsAction.length]];
        instrument.key = key.toUpperCase().charCodeAt(0);
        instrument.node = document.querySelector('[mod-instance="' + instrument.instance + '"]');
        instrument.keyboard = key;
        instrument.name = volumes[key].description;
        instrument.section = sections[sectionsAction[instrumentsAction.length]];
        instrument.sectionRank = 0;
        instrument.type = 'instrument';
        instrument.volume = key;
        instrumentsAction.push(instrument.code);
    }
    for (let key of Object.keys(loopers)) {
        let pad, selector;
        pad = pads[loopers[key].code] = Object.assign({}, pedals_families[loopers[key].family] || {}, loopers[key]);;
        pad.node = document.querySelector('[mod-instance="' + pad.instance + '"]');
        pad.bars = parseInt(pad.node.querySelector('[mod-port-symbol="bars"][class="mod-knob-value"]').innerText);
        pad.button = pad.node.querySelector('[mod-port-symbol="' + pad.symbol + '"]');
        pad.key = key.toUpperCase().charCodeAt(0);
        pad.type = 'pad';
        pad.keyboard = key;
        selector = '[mod-instance="' + pad.instance + '"][class="mod-pedal ui-draggable"]';
        pad.anchor = document.querySelector(selector).querySelector('[class="mod-drag-handle"]');
        pad.anchor.appendChild(document.createElement('h1'));
        pad.textNode = pad.anchor.children[0];
        pad.textNode.style.textAlign = 'center';
        pad.textNode.style.textShadow = '-1px 0 black, 0 1px black, 1px 0 black, 0 -1px black';
        if (pad.kind) {
            log('kind triggered with: ' + pad.kind);
            pads[pad.bars + pad.kind] = pad; //creating access like 2raw to facilitate transfer
        }
        if (instruments[pad.code]) {
            instruments[pad.code].pad = pad;
            pad.instrument = instruments[pad.code];
        }
/*        else {
            instruments[pad.code] = {};
            instruments[pad.code].pad = pad;
            pad.instrument = instruments[pad.code];
        }
*/
    }
    updateInstrumentsLabel();
    config = JSON.parse(GM_getValue('config'));
    config.engaged = false; //**** for testing purpose
    log('buildConfigAndAction loaded');
    setInterval(actionLoop, continuoStep);
}

function actionLoop() {
    if (config.engaged) {
        goThroughContinuos();
    }
}

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
        log('uI: inst ' + inst.key + ' : ' + inst.continuo.name);
        appendIconNode(inst.continuo.material, inst.section.color, inst.textNode);
        appendTextNode(inst.textNode, inst.continuo.keyboard + inst.section.keyboard, 'white');
    }
    for (let pad of Object.values(pads)) {
        pad.textNode.innerHTML = '';
        log('uI: pad ' + pad.key + ' : ' + pad.keyboard);
        appendTextNode(pad.textNode, pad.keyboard, pad.color);
    }
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

function getBPM () {
    return parseFloat(document.getElementById('mod-transport-icon').firstElementChild.innerHTML.match(/\d+(\.\d+)?/g, '')[0]);
}

function goThroughContinuos() {
    var continuo, continuoPeriod, currentSection, currentVolume, instrument, k, period, periodShift, port, rank, stepsToTarget, targetVolume, timePosition, volumes;
    period = 60 * 4 / bpm * 4; // 4 black notes, 4 times -> second length
    periodShift = 1 / continuosAction.length; //so that continuos have an equal repartition on a period //*** a bit unsure about that though, not all are used...
    // shouldn t timePosition be based on the continuo, its size, and its reference start point (to take in account pause, and change)
    // some part of rank should be based on continuo.size, and its position in the period should be based on sectionrank (and this should be section.rank)
    for (let instrument of Object.values(instruments)) {
        continuo = instrument.continuo;
        timePosition = (( Date.now() - (continuo.startTime || 0 )) / 1000 / period) % (4 * continuo.size);
        log (instrument.name + ' = ' + continuo.name + '-' + continuo.size + '.' + instrument.section.name + '-' + instrument.sectionRank + ', mode: ' + (continuo.mode || 'not set') + ' phase: ' + timePosition % (4 * rank));
        if (!continuo.size) { getContinuoSize(continuo); }
        if (!continuo.pause && continuo.size > 0) {
            volumes = instrument.volumes || pedals_families[instrument.family].volumes; //**** Where should it be stored, do continuo also have this
            port = document.querySelector('[mod-instance="' + instrument.instance + '"][class="mod-pedal ui-draggable"]').querySelector('[class="mod-knob-image mod-port"]');
            currentVolume = Math.round(parseInt(port.style.backgroundPositionX) / -1 / volumes.size);
            continuoPeriod = 4 * continuo.size; //8 = 4 * 2, 1 if there is two sections in the continuo
            rank = 4 * instrument.sectionRank; //in that case will be 0 & 4
            if (continuo.size == 1) {
                targetVolume = currentVolume < volumes.mid ? volumes.mid : volumes.high; //else it would be a too extreme change
            } else {
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
            moveMouse(port, stepsToTarget);
        }
        if (continuo.pause) {
            moveMouse(port, currentVolume);
        }
    }
}

function updateTitle(clicked) {
    page_title.innerHTML = '';
    if (clicked.instrument != null) {
        page_title.appendChild(createTextNode(clicked.instrument.name + ' instrument ' + clicked.instrument.keyboard + ', '));
    }
    if (clicked.newInstrument != null) {
        page_title.appendChild(createTextNode(clicked.newInstrument.symbol + ' ' + clicked.newInstrument.instance + ', '));
    }
    if (clicked.continuo != null) {
        log('continuo found');
        page_title.appendChild(createIconNode(clicked.continuo.material));
        page_title.appendChild(createTextNode(' continuo, '));
    }
    if (clicked.section != null) {
        page_title.appendChild(createTextNode(clicked.section.name + ' section, ', clicked.section.color));
    }
    if (clicked.action != null) {
        page_title.appendChild(createTextNode(' action:' + clicked.action.name + ', '));
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

function buttonDoubleClick (button) {
    setTimeout(function() {button.click();}, 0);
    setTimeout(function() {button.click();}, 250);
    return true;
}

function buttonBlink (button, r, g, b) {
    button.style.boxShadow = 'inset 0 0 0 100px rgba(' + (r || '255') + ',' + (g || '0') + ',' + (b || '150') + ',0.3)';
    setTimeout(function() { button.style.boxShadow = 'none'}, 100);
}

function highlight (element, off) {
    if (off) {
        element.style.boxShadow = null;
    } else {
        element.style.boxShadow = '0 0 0 10px red';
    }
    return true;
}

function clickInBarsBeats (pad) {
    setTimeout(function() {pad.button.click();}, 4 * pad.bars * beat);
    for (let i = 0; i < 2 * pad.bars; i++) {
        setTimeout(function() {buttonBlink(pad.button);}, ( 4 * i + 1) * beat);
        setTimeout(function() {buttonBlink(pad.button);}, ( 4 * i + 2) * beat);
        setTimeout(function() {buttonBlink(pad.button);}, ( 4 * i + 3) * beat);
        setTimeout(function() {buttonBlink(pad.button, '0', '0', '255');}, ( 4 * i + 4) * beat);
    }
}

function deleteClickedInstrument (clicked) {
    if (clicked.instrument) {
        highlight(clicked.instrument.node, true);
        if (clicked.instrument.pad) {
            highlight(clicked.instrument.pad.node, true);
        }
    }
    delete clicked.instrument;
    return true;
}

function updatePadBeat(pad) {
    log('uPB start, beat = ' + beat);
    if (pad.beat) {
        let span = Date.now() - pad.beat.start;
        let totalBeat = Math.round(span / beat);
        let padBeat = span / beat % 4;
        let padBeatProx = Math.round(padBeat);
        let next;
        log(span + ' ' + totalBeat + ' ' + padBeat + ' ' + padBeatProx);
        pad.beat.time = padBeatProx;
        if (Math.abs(padBeatProx - padBeat) < .2) {
            if (pad.beat.clickOn && pad.beat.clickOn == totalBeat) {
                pad.button.click();
                delete pad.beat.clickOn;
                log('uPB clicking');
            }
            if (padBeatProx == 0 || padBeatProx == 4) {
                log('tempo blink')
                buttonBlink(pad.button, '0', '0', '255');
            } else {
                log ('regular blink');
                buttonBlink(pad.button);
            }
        } else {
            log('uPB: far from target for ' + pad.instrument.name);
            if (pad.beat.clickOn && totalBeat > pad.beat.clickOn) {
                log('uPB: missed the clicking');
            }
        }
        next = Math.round((Math.floor(span / beat + 1) * beat - Date.now() + pad.beat.start));
        log('uPB, current beat: ' + pad.beat.time + ' next Beat in: ' + next);
        setTimeout(function() {log('new beat'); updatePadBeat(pad);}, next);
    }
    return true;
}

function checkActionable (clicked) {
    bpm = getBPM();
    log('cA clicked:');
    log(clicked);
    if (clicked.section != null && clicked.instrument != null) { //changing an instrument section
        if (clicked.section.name != clicked.instrument.section.name) {
            updateInstrumentAfterSectionChange(clicked.instrument, clicked.section, clicked.instrument.continuo);
            log('instrument sectionRank is: ' + clicked.instrument.sectionRank + ' in section ' + clicked.section.name);
            clicked.text = clicked.instrument.name +' instrument is now in section ' + clicked.instrument.section.name + ' of continuo ' + clicked.instrument.continuo.name;
            updateInstrumentsLabel();
            deleteClickedInstrument(clicked);
            delete clicked.section;
        } else {
            clicked.text = clicked.instrument.name + ' instrument already in section ' + clicked.section.name;
            deleteClickedInstrument(clicked);
            delete clicked.section;
        }
    }
    if (clicked.continuo != null && clicked.instrument != null) { //changing an instrument continuo
        if (clicked.continuo.name != clicked.instrument.continuo.name) {
            clicked.instrument.continuo = clicked.continuo;
            updateInstrumentAfterSectionChange(clicked.instrument, clicked.instrument.section, clicked.continuo);
            clicked.text = clicked.instrument.name +' instrument is now in section ' + clicked.instrument.section.name + ' of continuo ' + clicked.instrument.continuo.name;
            updateInstrumentsLabel();
            deleteClickedInstrument(clicked);
            delete clicked.continuo;
        } else {
            clicked.text = clicked.instrument.name + ' instrument already in continuo ' + clicked.continuo.name;
            deleteClickedInstrument(clicked);
            delete clicked.continuo;
        }
    }
    if (clicked.action != null && clicked.action.name == 'record' && clicked.instrument != null && clicked.instrument.pad) {
        let pad = clicked.instrument.pad;
        let button = pad.button;
        clicked.text = clicked.instrument.name + ': ';
        if (button.style.backgroundPosition == clicked.instrument.pad.clickedStyle) {
            button.click();
            clicked.text += 'silent - ';
        }
        buttonDoubleClick(button);
        pad.beat = {}; pad.beat.start = Date.now();
        pad.beat.clickOn = 4;
        //clickInBarsBeats(pad);
        updatePadBeat(pad)
        clicked.text += 'emptied & recording on 4th beat';
        deleteClickedInstrument(clicked);
        delete clicked.action;
    }
    if (clicked.action != null && clicked.action.name == 'loopClick' && clicked.instrument != null && clicked.instrument.pad) {
        let pad = clicked.instrument.pad;
        let button = pad.button;
        clicked.text = clicked.instrument.name + ' clicked, ';
        pad.button.click();
        delete clicked.action;
    }
    if (clicked.action != null && clicked.action.name == 'toggle' && clicked.instrument != null && clicked.instrument.pad) {
        let pad = clicked.instrument.pad;
        let button = pad.button;
        clicked.text = clicked.instrument.name + ' ';
        log(pad.button.style.backgroundPosition);
        if (pad.button.style.backgroundPosition != pad.clickedStyle) {
            for (let i = 0; i < pad.bars; i++) {
                setTimeout(function() {buttonBlink(pad.button);}, ( 4 * i + 1) * beat);
                setTimeout(function() {buttonBlink(pad.button);}, ( 4 * i + 2) * beat);
                setTimeout(function() {buttonBlink(pad.button);}, ( 4 * i + 3) * beat);
                setTimeout(function() {buttonBlink(pad.button, '0', '0', '255');}, ( 4 * i + 4) * beat);
            }
            clicked.text += 'playing or recording';
        } else {
            clicked.text += 'silent';
        }
        pad.button.click();
        deleteClickedInstrument(clicked);
        delete clicked.action;
    }
    if (clicked.action != null && clicked.action.name == 'pausePlayToggle') {
        log('cA seen here');
        switch (true) {
            case (clicked.hasOwnProperty('instrument')):
                log('cA and there');
                clicked.text = clicked.instrument.name + ' reseted';
                if (clicked.instrument.pad.button.style.backgroundPosition == clicked.instrument.pad.clickedStyle) {
                    clicked.instrument.pad.button.click();
                }
                buttonDoubleClick(clicked.instrument.pad.button);
                deleteClickedInstrument(clicked);
                break;
            case (clicked.hasOwnProperty('section')):
                clicked.text = clicked.section.name + ' pause not handled yet';
                delete clicked.section;
                break;
            case (clicked.hasOwnProperty('continuo')):
                clicked.continuo.pause = clicked.continuo.pause ? false: true;
                clicked.text = clicked.continuo.name;
                delete clicked.continuo;
                break;
            default:
                clicked.text = ' everything pause not handled yet';
                break;
        }
        delete clicked.action;
    }
    if (clicked.action != null && clicked.action.name == 'engagement') {
        config.engaged = config.engaged ? false : true;
        clicked.text = config.engaged ? 'tamperMod engaged' : 'tamperMod disengaged'; //*** not really though, need to set all volumes to 0, maybe found a restore also
        delete clicked.action;
    }
    if (clicked.action != null && (clicked.action.name == 'increaseVolume' || clicked.action.name == 'decreaseVolume')) {
        for (let inst of Object.values(instruments)) {
            let changeVolume = false;
            changeVolume = (clicked.instrument && clicked.instrument.name == inst.name);
            changeVolume = changeVolume || (clicked.section && clicked.continuo && inst.section.name == clicked.section.name && inst.continuo.name == clicked.continuo.name);
            changeVolume = changeVolume || (!clicked.section && clicked.continuo && inst.continuo.name == clicked.continuo.name);
            changeVolume = changeVolume || (clicked.section && !clicked.continuo && inst.section.name == clicked.section.name);
            //***** changeVolume true -> update instrument (it looks like a similar selection than for highlight box if needed)
        }
    }
    if (clicked.action != null && clicked.action.name == 'transfer' && clicked.instrument && clicked.instrument.pad) {
        let pad = clicked.instrument.pad;
        let raw = pads[pad.bars + 'raw'];
        log('cA pad ' + pad.code + ' : ' + pad.bars + 'raw');
        log(raw);
        let instrumentName = clicked.instrument.name;
        if (raw) {
            if (raw.button.style.backgroundPosition != raw.clickedStyle) {
                raw.button.click();
            }
            if (pad.button.style.backgroundPosition == pad.clickedStyle) {
                pad.button.click();
            }
            buttonDoubleClick(pad.button);
            pad.button.click(); //*** is the last click of the doubleclick before or after this click ? might be better to be in order
            setTimeout(function(){
                raw.button.click();
                buttonDoubleClick(raw.button);
                clicked.text = 'complete transfer of raw ' + pad.bars + ' to ' + instrumentName + ' and clean up';
                updateTitle(clicked);
            }, pad.bars * 60 / bpm * 1000); //**** is this timing too strict ? does it have the right length
            clicked.text = 'transferring raw ' + pad.bars + ' to ' + instrumentName + ' and cleaning it afterwards';
            delete clicked.action;
            deleteClickedInstrument(clicked);
        } else {
            delete clicked.action;
            clicked.text = 'transfer failed: no matching raw looper for ' + pad.bars + ' bars like ' + clicked.instrument.name;
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
    document.addEventListener('keydown', function (keyEvent) { //https://javascript.info/keyboard-events
        var conf, fade_direction, id, knob, period, port, instNumber;
        log (keyEvent.code + ' key was pressed.');
        // https://unicode-table.com/en/#control-character
        // https://unicodelookup.com/
        if (instruments[keyEvent.code]) {
            if (clicked.instrument && clicked.instrument.code == keyEvent.code) {
                deleteClickedInstrument(clicked);
            } else {
                if (clicked.instrument) {
                    deleteClickedInstrument(clicked);
                }
                clicked.instrument = instruments[keyEvent.code];
                highlight(clicked.instrument.node);
                if (clicked.instrument.pad) {
                    highlight(clicked.instrument.pad.node);
                }
            }
        }
        if (sectionsAction.indexOf(keyEvent.code) > -1) {
            clicked.section = sections[keyEvent.code];
        }
        if (continuosAction.indexOf(keyEvent.code) > -1) {
            clicked.continuo = continuos[keyEvent.code];
        }
        if (generalActions[keyEvent.code]) {
            if (clicked.action && (clicked.action.name == generalActions[keyEvent.code].name)) {
                delete clicked.action;
            } else {
                clicked.action = generalActions[keyEvent.code];
            }
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
