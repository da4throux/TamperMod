// ==UserScript==
// @name         TamperMod
// @namespace    http://tampermonkey.net/
// @version      0.3.11
// @description  Help automate some dynamic gesture when using the Mod Duo X
// @author       da4throux
// @match        http://moddwarf.local/*
// @grant_not        GM_xmlhttpRequest //should not be needed anymore
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_getResourceText
// @grant        GM_addStyle
// @grant        unsafeWindow
// @icon         http://192.168.51.1/img/icons/36/mod.png
// @run-at       document-idle
// @resource     MaterialIcons https://fonts.googleapis.com/icon?family=Material+Icons

// ==/UserScript==

/** tested on: http://192.168.51.1/?v=1.9.3.1776
// with: 1910 SETUP TAMPER pedalboard

//** (bug): sectionRank and scale updated from start (it was often 0/undefined)
//** (bug): updatePadLabel when transfering (state: transfering and once finished)

//** increase decrease volume
//** color code the tinyGain to make more visible where there is sound (muted, silent, low, normal, max)
//** possibility to get an average output dB and sync the volume: or min and max over the last sliding minute for example (keep all the tops for every seconds)
//** make engagement specific to some continuo not all
//** delete after a number of bars
//** decrease dynamically the time base of the sync (to make it faster or slower)
//** a minimum slope -> change the slope instead of the length ?
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
//** /Slash\BackSlash keys to use a fade in and out if needed
//** Indicate the length of the fade in bars
//** instant silence [ ]: to open and close it ?
**/

const MaterialIcons = GM_getResourceText("MaterialIcons");
GM_addStyle(MaterialIcons);
// https://material.io/resources/icons/?style=baseline
// <i class="material-icons">aspect_ratio</i>

const logLevel = 10;
const logFilter = "always mute"; //cA steps uPB
const logMods = ['FocusOnFilter', 'FilterOrLevel', 'FilterAndLevel', 'FocusOnSearch']; //FocusOnFilter: everything from the filter only goes through - Search not great when needing to log object...
const logMod = 2;

function log(message, levelOrOrigin, level) {
    let origin, log;
    //console.log (log.caller);
    //10 = Debug, 20 = Info, 40 = Error // https://docs.python.org/2.4/lib/module-logging.html
    log = false;
    origin = typeof levelOrOrigin == "string" ? levelOrOrigin : "shouldNotBeLogged";
    level = typeof levelOrOrigin == "string" ? level || 15 : levelOrOrigin || 15;
    switch (logMod) {
        case 0:
            log = logFilter.includes(origin);
            break;
        case 1:
            log = logFilter.includes(origin) || level >= logLevel;
            break;
        case 2:
            log = logFilter.includes(origin) && level >= logLevel;
            break;
        case 3:
            log = logFilter.split(" ").some(f => origin.includes(f));
            break;
    }
    if (log) {
        console.log(typeof message == 'string' ? 'TamperMod-' + origin + ':' + message : message);
    }
}

const icons = { // https://keycode.info/
    a: {
        name: 'arrow',
        material: 'call_made',
        code: 'KeyA'
    },
    c: {
        name: 'circle',
        material: 'fiber_manual_record',
        code: 'KeyC',
    },
    e: {
        name: 'eye',
        material: 'visibility',
        code: 'KeyE'
    },
    h: {
        name: 'heart',
        material: 'favorite',
        code: 'KeyH'
    },
    m: {
        name: 'mobile',
        material: 'stay_primary_portrait',
        code: 'KeyM'
    },
    s: {
        name: 'star',
        material: 'grade',
        code: 'KeyS'
    },
    f: {
        name: 'facebook',
        material: 'thumb_up',
        code: 'KeyF'
    },
    v: { //could be a toggle - or should the icon be greyed
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
    b: {
        name: 'blue',
        code: 'KeyB'
    },
    g: {
        name: 'green',
        code: 'KeyG'
    },
    o: {
        name: 'orange',
        code: 'KeyO'
    },
    p: {
        name: 'purple',
        code: 'KeyP'
    },
    r: {
        name: 'red',
        code: 'KeyR'
    },
    w: {
        name: 'white',
        code: 'KeyW'
    },
    y: {
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

// Todo:

// fadeout does not seem to work in mode fade
// might be an issue if the target is the actual value
// the interruption to switch to another effect on the same knob does not seem to work
// fade -Enter- does not seem to land exactly on 0 when starting from -40dB

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

function triggerMouseEvent(node, eventType) {
    var clickEvent = document.createEvent('MouseEvents');
    clickEvent.initEvent(eventType, true, true);
    node.dispatchEvent(clickEvent);
}

function triggerEvent(target, type) {
    "use strict";
    var event = document.createEvent('HTMLEvents');
    event.initEvent(type, true, true);
    target.dispatchEvent(event);
}

function simulateMouseEvent(target, type, clientX, clientY) {
    //https://stackoverflow.com/questions/9749910/programmatically-triggering-mouse-move-event-in-javascript
    var rect = target.getBoundingClientRect();
    log('SME - unsafeWindow: ' + typeof unsafeWindow, 1);
    log(unsafeWindow, 1);
    log('x-y' + clientX + '-' + clientY, 'sME', 1);
    var event = new MouseEvent(type, {
        'view': unsafeWindow,
        'bubbles': true,
        'cancelable': true,
        'clientX': clientX,
        'clientY': clientY,
        // you can pass any other needed properties here
    });
    target.dispatchEvent(event);
};

const timeStep = 0.2; // minimum step for each action (every .2s I would change the volume knob)
const continuoStep = 2000;
const maxPeriod = 10000; //any action taking more than a second should be reduce to this xx ms - I'm thinking of turning the knob for a fadeOut
var bpm, beat, actionSpan = 2;
var page_title, page_title_original, x = 0, y = 0;
var config_default = {};
var config = {},
    volumes, pedals_families = {}, pedals_types = {}, loopers, levels; // keep track of buttons involved in the orchestra (continuos / sections) - before I was thinking of actions, this reverse the approach
// I need to build this from configuration:
// document.querySelector('[mod-instance="/graph/Gain_1"][class="mod-pedal ui-draggable"]').querySelector('[mod-port="/graph/Gain_1/Gain"]')
// when browsing above a pedal, get all its potential control:
//  - document.querySelector('[mod-instance="/graph/mono_8"]').querySelectorAll('[mod-port]').forEach(function(node){console.log(node.getAttribute('mod-port'));})
const defaultBeatRGB = ['100', '100', '0', '0.8']; //default beat is yellow
const recordBeatRGB = ['255', '000', '0', '0.6']; //record color is red
const upBeatRGB = ['0', '0', '255', '0.8']; // upBeat is blue
const DB_LOW = -60;
const DB_HIGH = -10;
const DB_SILENT = '-inf';
var actions = []; //need to track for eacth instance/symbol the current action if any
var active_actions = {}; //hash by port of ID of current effect if any
var styles = {
    'fade-out': "crimson",
    'fade-in': "blue",
    'stable': "lime",
};
var fade_colors = {
    '-1': 'blue',
    '1': 'crimson'
};
var default_filter = 'drop-shadow(20px 6px 20px Fuchsia)';

function knob_style(remaining_steps, type) { //number of steps away from target, fade_in/out...
    var _style = 'drop-shadow(';
    _style += Math.round(remaining_steps / 64 * 30) + 'px 6px ' + Math.round(remaining_steps / 64 * 30) + 'px ' + styles[type] + ')';
    return _style;
}

function port_style(remaining_steps, direction) { //number of steps away from target, fade_in/out...
    var _style = 'drop-shadow(';
    _style += Math.round(remaining_steps / 64 * 30) + 'px 6px ' + Math.round(remaining_steps / 64 * 30) + 'px ' + fade_colors[direction] + ')';
    return _style;
}

pedals_families = {
    Gain: {
        symbol: 'Gain',
        description: 'simple V3 pedal, v3 knob',
        subFamily: 'volume',
        steps: 65,
        size: 98,
        volumes: {
            low: 0,
            mid: 24,
            high: 32,
            size: 98
        },
        getVolume: function () {
            return Math.round(parseInt(this.port.style.backgroundPositionX) / -1 / this.volumes.size);
        },
    },
    Alo: {
        clickedStyle: '-71px 0px', //the backgroundPosition when clicked
        symbol: "loop1",
        color: "yellow",
        subFamily: 'looper',
    },
    tinyGain: {
        symbol: 'level',
        subFamily: 'level',
        description: 'level indication', //check if the instrument is making sounds, look for high/low levels in the recent bars
    }
};

//*** I kind of set a limit to 10 loops (0 to 9) - ok for the time being I guess
volumes = {
    0: {
        instance: "/graph/mono_1",
        description: "V3 pedal general",
        family: "Gain",
        code: "Digit0"
    },
    1: {
        instance: "/graph/Gain",
        description: "V3 pedal BOTTOM looper",
        family: "Gain",
        code: "Digit1"
    },
    2: {
        instance: "/graph/Gain_2",
        description: "V3 direct",
        family: "Gain",
        code: "Digit2"
    },
    3: {
        instance: "/graph/Gain_3",
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

levels = {
    0: {
        instance: "/graph/mono",
        family: 'tinyGain',
    },
    1: {
        instance: "/graph/mono_6",
        family: 'tinyGain',
    },
    3: {
        instance: "/graph/mono_4",
        family: 'tinyGain',
    },
};


var instruments = {}, instrumentsAction = [];
var pads = {};
//continuos = [[0, 1]]; // instruments from section 0 & 1 are alternating in one continuo

//if (!GM_getValue('config')) {
config_default.actions = {};
var generalActions = {};
generalActions = {
    Space: { //V3 off button toogle
        type: 'action',
        keyboard: 'space',
        description: 'toggle tamperMod engagement (recommended for web page direct interaction)',
        name: 'engagement',
    },
    Period: {
        type: 'action',
        keyboard: '.',
        description: 'raw toggle the associated loop', //i.e. no handling of bars or beats
        name: 'loopClick',
    },
    Minus: {
        type: 'action',
        keyboard: '-', //between - and _ (sound / no sound) //Alo keeps the rythm of the loop running though
        description: 'one Click - start or stop the playing of the loop on its next cycle',
        name: 'toggle',
    },
    Equal: {
        type: 'action',
        keyboard: '=', //the + sign on top of it: adding a sound
        description: 'double click silence, and will start recording on the 4th beat',
        name: 'record',
    },
    Backquote: {
        type: 'action',
        keyboard: '~', // key on the left of 1
        description: 'transfer raw loop', //there's only one compatible raw loop, so it can be selected automatically
        name: 'transfer',
    },
    Backspace: {
        type: 'action',
        keyboard: 'backspace',
        description: 'clean a loop',
        name: 'delete',
    },
    ArrowUp: {
        type: 'action',
        keyboard: 'up',
        description: 'increase volume', //vs increase targetVolume threshold (low-mid-high vs changing one of those)?
        name: 'increaseVolume',
    },
    ArrowDown: {
        type: 'action',
        keyboard: 'down',
        description: 'decrease volume',
        name: 'decreaseVolume',
    },
    ArrowLeft: {
        type: 'action',
        keyboard: 'left',
        description: 'decrease default bar length for action',
        name: 'decreaseActionSpan'
    },
    ArrowRight: {
        type: 'action',
        keyboard: 'right',
        description: 'increase default bar length for action',
        name: 'increaseActionSpan'
    }
}

config_default = JSON.stringify(config_default);
GM_setValue('config', config_default);
log('GM_setValue done', config_default, typeof GM_setValue.then); //
//}

function buildConfigAndActions() {
    var i;
    bpm = getBPM(); beat = 60 / bpm * 1000; //beat is in ms
    //    investigationOfModPorts();
    page_title_original = document.getElementById('pedalboard-info').children[0].innerHTML;
    page_title = document.getElementById('pedalboard-info').children[0];
    page_title.style.textTransform = 'none';
    for (let key of Object.keys(volumes)) {
        let instrument = instruments[volumes[key].code] = Object.assign({}, pedals_families[volumes[key].family], volumes[key]);
        if (document.querySelector('[mod-instance="' + instrument.instance + '"][class="mod-pedal ui-draggable"]') == null) {
            console.log('TamperMonkey error in config, missing instrument: ' + key + ' - ' + instrument.instance);
            delete instruments[volumes[key].code]; delete volumes[key];
            continue;
        }
        console.log('TamperMonkey adding instrument: ' + key + ' - ' + instrument.instance);
        instrument.continuo = continuos[continuosAction[instrumentsAction.length]];
        instrument.continuo.size = 1;
        instrument.key = key.toUpperCase().charCodeAt(0);
        instrument.node = document.querySelector('[mod-instance="' + instrument.instance + '"]');
        instrument.keyboard = key;
        instrument.name = volumes[key].description;
        instrument.section = sections[sectionsAction[instrumentsAction.length]];
        instrument.sectionRank = 0;
        instrument.type = 'instrument';
        instrument.volume = key;
        instrument.port = document.querySelector('[mod-instance="' + instrument.instance + '"][class="mod-pedal ui-draggable"]').querySelector('[class="mod-knob-image mod-port"]');
        instrument.targetStartVolume = instrument.targetVolume = instrument.getVolume();
        instrument.title = instrument.node;
        instrument.titlePlus = '';
        instrument.setTitle = function () {
            var title;
            title = instrument.keyboard + ' in section ' + this.section.name + ' rank ' + (this.sectionRank + 1) + '/' + this.continuo.size + ' of continuo ' + instrument.continuo.name + '\n';
            if (instrument.getVolume() != instrument.targetVolume) {
                title += 'volume: ' + this.getVolume() + ' -> ' + instrument.targetVolume + ' in ' + Math.floor((instrument.targetTime - Date.now()) / 100) / 10 + 's\n';
            } else {
                title += 'volume: ' + this.getVolume() + ' stable\n';
            }
            if (instrument.pad) {
                title += 'bars: ' + instrument.pad.bars + ', state: ' + instrument.pad.state;
            }
            title += this.titlePlus || '';
            this.titlePlus = '';
            instrument.title.setAttribute("title", title);
        }
        instrumentsAction.push(instrument.code);
        instrument.setTitle();
        if (levels[key]) {
            instrument.level = document.querySelector('[mod-instance="' + levels[key].instance + '"][class="mod-pedal ui-draggable"]');
            instrument.mute = document.querySelector('[mod-instance="' + levels[key].instance + '"][class="mod-settings"]').querySelector('[class="mod-switch-image mod-port"]');
            instrument.getLevel = function () {
                return instrument.level.querySelector('[class="db"]').innerText;
            }
            instrument.toggleMute = function () {
                instrument.mute.click();
            }
            instrument.isMuted = function () {
                log(instrument.keyboard + ' is muted: ' + (instrument.mute.style.backgroundPosition != "0px 0px"), 'mute');
                return (instrument.mute.style.backgroundPosition != "0px 0px");
            }
        }
    }
    for (let key of Object.keys(loopers)) {
        let pad, selector;
        pad = pads[loopers[key].code] = Object.assign({}, pedals_families[loopers[key].family] || {}, loopers[key]);;
        pad.node = document.querySelector('[mod-instance="' + pad.instance + '"]');
        if (pad.node == null) {
            console.log('TamperMonkey error in config, missing looper: ' + key + ' - ' + pad.instance);
            delete pads[loopers[key].code]; delete loopers[key];
            continue;
        }
        console.log('TamperMonkey adding looper: ' + key + ' - ' + pad.instance);
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
        pad.state = 'N/A';
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
    config.engaged = false; //by default no auto regulation
    log('buildConfigAndAction loaded');
    setInterval(actionLoop, continuoStep);
}

function actionLoop() { //separate calculating the target Volume from setting them. Several ways to calculate the target volumes
    if (config.engaged) {
        goThroughContinuos(); //current way to update targetVolumes
    }
    updateVolumes();
}

function updateVolumes() { //**** need to validate: seems to be too fast.
    let currentVolume, instantTarget, stepsToTarget;
    //            stepsToTarget = Math.round(continuoStep * (currentVolume - targetVolume) / (1 - timePosition % 1) / period / 1000);
    //            moveMouse(instrument.port, stepsToTarget);
    for (let inst of Object.values(instruments)) {
        currentVolume = inst.getVolume();
        if (inst.targetVolume != currentVolume) {
            if (inst.targetTime != inst.targetStartTime) {
                if (inst.targetTime > Date.now()) {
                    instantTarget = Math.round(inst.targetStartVolume + inst.targetSlope * (Date.now() - inst.targetStartTime));
                    log('instantTarget ' + instantTarget, 'steps');
                } else {
                    instantTarget = inst.targetVolume;
                    log('overTime for targetTime: ' + inst.targetTime + ' and Now: ' + Date.now(), 'steps');
                }
                stepsToTarget = instantTarget - currentVolume;
                if (inst.keyboard == 0) {
                    log('stepsToTarget.' + inst.keyboard + ': ' + stepsToTarget + ', ' + inst.targetStartVolume + '(' + currentVolume + ')->' + inst.targetVolume, 'steps');
                    log('Now1: ' + Date.now() + ', TargetTime: ' + inst.targetTime + ', delta: ' + inst.targetTime, 'steps');
                    log(Math.floor((inst.targetTime - Date.now()) / 100) / 10 + 's', 'steps');
                    log('slope: ' + inst.targetSlope + ', tStartV3: ' + inst.targetStartVolume + ', instantTarget: ' + instantTarget, 'steps');
                }
                moveMouse(inst.port, -stepsToTarget);
            }
        } else {
            //            log('on target.' + inst.keyboard + ': ' + inst.targetStartVolume + '(' + currentVolume + ')->' + inst.targetVolume , 'steps');
        }
        inst.setTitle();
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
    if (size) {
        textNode.style.fontSize = size;
    }
    return textNode;
}

function appendTextNode(node, text, color, size) {
    var textNode = createTextNode(text, color || 'green', size || 'x-large');
    textNode.style.fontWeight = 'bolder';
    textNode.style.textAlign = 'center';
    node.appendChild(textNode);
    return true;
}

function updatePadLabel(pad) {
    var text, level;
    pad.textNode.innerHTML = '';
    text = pad.keyboard;
    if (pad.positionBar) {
        if (pad.state && pad.state == 'recording' && Date.now() < pad.stateStartTime) {
            text += '_record in: ' + (5 - pad.positionBeat);
        } else {
            text += '_' + pad.state + ': ' + pad.positionBar + '.' + pad.positionBeat;
        }
    } else {
        text += '_' + pad.state;
    }
    if (pad.instrument.level) {
        level = pad.instrument.getLevel();
        switch (true) {
            case (level == DB_SILENT):
                text += '_silent';
                break;
            case (level < DB_LOW):
                text += '_low';
                break;
            case (level >= DB_LOW && level < DB_HIGH):
                text += '_noisy';
                break;
            case (level >= DB_HIGH):
                text += '_loud';
                break;
        }
    }
    if (pad.instrument.isMuted()) {
        text += '_muted';
    }
    log(text, 'uPB');
    appendTextNode(pad.textNode, text, pad.color);
}

function updateInstrumentsLabel() {
    var selector;
    for (let inst of Object.values(instruments)) {
        selector = '[mod-instance="' + inst.instance + '"][class="mod-pedal ui-draggable"]';
        inst.anchor = document.querySelector(selector).querySelector('[class="mod-drag-handle"]');
        //        inst.textNode = document.querySelector(selector).querySelector('[class="mod-plugin-brand"]').children[0]; //h1 ***** change from MDX or miniGain ?
        inst.dbLabel = document.querySelector(selector).querySelector('[class="db-label"]');
        inst.textNode = inst.dbLabel.children[0]; //h1
        inst.textNode.innerHTML = '';
        appendTextNode(inst.textNode, inst.keyboard, 'white');
        appendIconNode(inst.continuo.material, inst.section.color, inst.textNode);
        appendTextNode(inst.textNode, inst.continuo.keyboard + inst.section.keyboard, 'white');
        inst.dbLabel.style.transform = "translateY(40px)" //***** would be better positioned above the bin and settings (all the same !)
    }
    for (let pad of Object.values(pads)) {
        updatePadLabel(pad);
    }
}

function moveMouse(port, stepsToTarget) {
    ["mouseover", "mousedown"].forEach(function (eventType) { triggerMouseEvent(port, eventType); });
    simulateMouseEvent(port, 'mousemove', x, y + 2 * stepsToTarget);
    ["mouseup", "click"].forEach(function (eventType) { triggerMouseEvent(port, eventType); });
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

function getBPM() {
    return parseFloat(document.getElementById('mod-transport-icon').firstElementChild.innerHTML.match(/\d+(\.\d+)?/g, '')[0]);
}

function goThroughContinuos() {
    var bar, continuo, continuoPeriod, currentSection, currentVolume, instrument, k, period, periodShift, port, rank, stepsToTarget, targetVolume, timeCycle, timePosition, volumes;
    bar = 60 * 4 / bpm; //seconds 4 black notes -> one bar
    period = actionSpan * bar; //seconds 4 black notes, actionSpan times
    periodShift = 1 / continuosAction.length; //so that continuos have an equal repartition on a period //*** a bit unsure about that though, not all are used...
    // shouldn t timePosition be based on the continuo, its size, and its reference start point (to take in account pause, and change)
    // some part of rank should be based on continuo.size, and its position in the period should be based on sectionrank (and this should be section.rank)
    for (let instrument of Object.values(instruments)) {
        continuo = instrument.continuo;
        if (!continuo.size) { getContinuoSize(continuo); }
        if (!continuo.startTime) { continuo.startTime = Date.now(); }
        log(continuo.startTime + ' : ' + period + ' : ' + continuo.size, 1);
        timePosition = ((Date.now() - continuo.startTime) / 1000 / period) % (4 * continuo.size); //bar position in the whole continuo cycle (including all sections)
        timeCycle = Math.floor((Date.now() - continuo.startTime) / 1000 / period); //s how many period occured since the beginning of the continuo
        log(instrument.name + ' = ' + continuo.name + '-' + continuo.size + '.' + instrument.section.name + '-' + instrument.sectionRank + ', mode: ' + (continuo.mode || 'not set') + ' phase: ' + timePosition % (4 * rank));
        if (!continuo.pause && continuo.size > 0) {
            volumes = instrument.volumes || pedals_families[instrument.family].volumes; //*** Where should it be stored, should continuo also have this ?
            currentVolume = instrument.getVolume();
            continuoPeriod = 4 * continuo.size; //8 = 4 * 2 (-> the number of sections in the continuo)
            rank = 4 * instrument.sectionRank; //in that case will be 0 & 4 (order of passage as maximum volume)
            if (continuo.size == 1) {
                targetVolume = currentVolume < volumes.mid ? volumes.mid : volumes.high; //else it would be a too extreme change
            } else {
                switch (true) {
                    case ((timePosition > rank) && (timePosition < (rank + 3))):
                        targetVolume = currentVolume < volumes.mid ? volumes.mid : volumes.high;
                        instrument.titlePlus = 'will be at ' + volumes.high + ' for ' + Math.floor(((rank + 3) * period * 1000 + continuo.startTime - Date.now()) / 100) / 10 + 's';
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
                        instrument.titlePlus = 'will be at ' + volumes.low + ' for some time';
                        break;
                }
            }
            if (instrument.targetVolume != targetVolume) { //need to set new Target
                instrument.targetStartVolume = currentVolume;
                instrument.targetVolume = targetVolume;
                instrument.targetStartTime = Date.now(); //ms
                instrument.targetTime = continuo.startTime + (timeCycle + 1) * period * 1000; //ms
                instrument.targetSlope = (targetVolume - instrument.targetStartVolume) / (instrument.targetTime - instrument.targetStartTime);
                if (instrument.keyboard == 0) {
                    log('continuo setting.' + instrument.keyboard + ': ' + instrument.targetStartVolume + '->' + instrument.targetVolume + ' in ' + Math.round((instrument.targetTime - instrument.targetStartTime) / 100) / 10 + 's', 'steps');
                    log('startTime: ' + Date.now() + ', period ms: ' + period * 1000 + ', targetTime: ' + instrument.targetTime, 'steps');
                }
            }
            stepsToTarget = Math.round(continuoStep * (currentVolume - targetVolume) / (1 - timePosition % 1) / period / 1000);
            //            moveMouse(instrument.port, stepsToTarget); //should be done now in external function
        }
        if (continuo.pause) {
            log('gTC: continuo.paused ?', 'always');
            moveMouse(instrument.port, currentVolume); //*** unclear to me now 191021
        }
    }
}

function setEngagedVisibility(visible) { //** there could be other states though //engage Mode is less compatible with mouse movement
    document.getElementById('pedalboard-actions').style.boxShadow = visible ? '0 2px 12px red' : null;
}

function updateTitle(clicked) {
    page_title.innerHTML = '';
    setEngagedVisibility(config.engaged);
    if (clicked.text != null) {
        page_title.appendChild(createTextNode(clicked.text));
        clicked.text = '';
    }
    if (clicked.instrument != null) {
        page_title.appendChild(createTextNode('inst ' + clicked.instrument.keyboard + ', '));
    }
    if (clicked.newInstrument != null) {
        page_title.appendChild(createTextNode(clicked.newInstrument.symbol + ' ' + clicked.newInstrument.instance + ', '));
    }
    if (clicked.continuo != null) {
        page_title.appendChild(createIconNode(clicked.continuo.material));
        page_title.appendChild(createTextNode(' continuo, '));
    }
    if (clicked.section != null) {
        page_title.appendChild(createTextNode(clicked.section.name + ' section, ', clicked.section.color));
    }
    if (clicked.action != null) {
        page_title.appendChild(createTextNode(' action:' + clicked.action.name + ', '));
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

function cleanLoop(pad) {
    if (pad.button.style.backgroundPosition == pad.clickedStyle) {
        pad.button.click();
    }
    buttonDoubleClick(pad.button);
    delete pad.beat;
    pad.state = 'empty';
    log('emptied pad ' + pad.keyboard, 'mute');
    updatePadLabel(pad);
    return true;
}

function startLoop(pad, bars) {
    pad.beat = {}; pad.beat.start = Date.now();
    if (bars) {
        pad.beat.clickOn = bars;
    } else {
        if (pad.button.style.backgroundPosition != pad.clickedStyle) {
            pad.button.click();
        }
    }
    if (!pad.updateBeat) { updatePadBeat(pad); }
    return true;
}

function buttonDoubleClick(button) {
    setTimeout(function () { button.click(); }, 0);
    setTimeout(function () { button.click(); }, 250);
    return true;
}

function padBlink(pad, r, g, b, l) {
    var button = pad.button;
    button.style.boxShadow = 'inset 0 0 0 100px rgba(' + (r || defaultBeatRGB[0]) + ',' + (g || defaultBeatRGB[1]) + ',' + (b || defaultBeatRGB[2]) + ',' + (l || defaultBeatRGB[3]) + ')';
    setTimeout(function () {
        if (pad.state && pad.state == 'recording' && Date.now() > pad.stateStartTime) {
            button.style.boxShadow = 'inset 0 0 0 100px rgba(' + (r || recordBeatRGB[0]) + ',' + (g || recordBeatRGB[1]) + ',' + (b || recordBeatRGB[2]) + ',' + recordBeatRGB[3] + ')';
        } else {
            button.style.boxShadow = 'none';
        }
    }, 100);
}

function highlight(element, off) {
    if (off) {
        element.style.boxShadow = null;
    } else {
        element.style.boxShadow = '0 0 0 10px red';
    }
    return true;
}

function deleteClickedInstrument(clicked) {
    if (clicked.instrument) {
        highlight(clicked.instrument.node, true);
        if (clicked.instrument.pad) {
            highlight(clicked.instrument.pad.node, true);
        }
        if (clicked.instrument.level) {
            highlight(clicked.instrument.level, true);
        }
    }
    delete clicked.instrument;
    return true;
}

function updatePadBeat(pad) {
    //pad.updateBeat: there's already some updatePadBeat setTimeOut going on, so no need to trigger more, just ride the current wave
    //pad.beat: object that describe the beat
    //pad.state + pad.stateStartTime: used to know if we are in 'record' state -> to set the default color (red for recording, nothing else)
    log('uPB start, beat = ' + beat, 'uPB');
    if (pad.beat) {
        pad.updateBeat = true;
        if (pad.state == 'recording' && Date.now() > pad.stateStartTime) {
            pad.beat.start = pad.stateStartTime; //the new beat start is the recording start
        }
        if (pad.nextState && Date.now() > pad.stateEndTime) {
            pad.state = pad.nextState;
            delete pad.nextState;
        }
        if (pad.stateEndTime && Date.now() > pad.stateEndTime) {
            pad.stateEndTime += pad.bars * 4 * 1000 * 60 / bpm;
        }
        let span = Date.now() - pad.beat.start;
        let totalBeat = Math.round(span / beat);
        let padBeat = span / beat % 4;
        pad.positionBar = Math.floor(span / beat / 4 % (pad.bars)) + 1;
        let padBeatProx = Math.round(padBeat);
        log(span + ' ' + totalBeat + ' ' + padBeat + ' ' + padBeatProx);
        pad.beat.time = padBeatProx;
        if (Math.abs(padBeatProx - padBeat) < .2) {
            if (pad.beat.clickOn && pad.beat.clickOn == totalBeat) {
                pad.button.click();
                delete pad.beat.clickOn;
                log('uPB clicking', 'uPB');
            }
            if (pad.beat.clickOff && pad.beat.clickOff == totalBeat) {
                pad.updateBeat = false;
                cleanLoop(pad);
            }
            if (padBeatProx == 0 || padBeatProx == 4) {
                log('tempo blink', 'uPB')
                padBlink(pad, upBeatRGB[0], upBeatRGB[1], upBeatRGB[2], upBeatRGB[3]); //Blue beat on the Bar
                pad.positionBeat = 1;
            } else {
                log('regular blink', 'uPB');
                padBlink(pad);
                pad.positionBeat = padBeatProx + 1;
            }
        } else {
            log('uPB: far from target for ' + pad.instrument.name, 'uPB');
            if (pad.beat.clickOn && totalBeat > pad.beat.clickOn) {
                log('uPB: missed the clicking', 'uPB');
            }
        }
    } else {
        pad.updateBeat = false;
        pad.state = 'empty'; //delete pad.state;
        delete pad.positionBar;
        delete pad.positionBeat;
        updatePadLabel(pad);
    }
    if (pad.updateBeat) {
        let next;
        let span = Date.now() - pad.beat.start;
        updatePadLabel(pad);
        next = Math.round((Math.floor(span / beat + 1) * beat - Date.now() + pad.beat.start));
        log('uPB, current beat: ' + pad.beat.time + ' next Beat in: ' + next, 'uPB');
        setTimeout(function () { log('new beat'); updatePadBeat(pad); }, next);
    }
    return true;
}

function checkActionable(clicked) {
    bpm = getBPM();
    log('cA clicked:');
    log(clicked);
    if (clicked.section != null && clicked.instrument != null) { //changing an instrument section
        if (clicked.section.name != clicked.instrument.section.name) {
            updateInstrumentAfterSectionChange(clicked.instrument, clicked.section, clicked.instrument.continuo);
            log('instrument sectionRank is: ' + clicked.instrument.sectionRank + ' in section ' + clicked.section.name);
            clicked.text = clicked.instrument.name + ' instrument is now in section ' + clicked.instrument.section.name + ' of continuo ' + clicked.instrument.continuo.name;
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
            clicked.text = clicked.instrument.name + ' instrument is now in section ' + clicked.instrument.section.name + ' of continuo ' + clicked.instrument.continuo.name;
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
        cleanLoop(pad);
        pad.state = 'recording';
        pad.nextState = 'playing';
        pad.stateStartTime = Date.now() + 4 * 60 / bpm * 1000; //ms in 1 bar it will start recording
        pad.stateEndTime = pad.stateStartTime + pad.bars * 4 * 60 / bpm * 1000; //ms and after 4 * pad.bars it should stop recording
        pad.beat = {}; pad.beat.start = Date.now();
        pad.beat.clickOn = 4;
        if (!pad.updateBeat) { updatePadBeat(pad); }
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
            if (!pad.updateBeat) {
                clicked.text += 'record a loop first with +';
                pad.state = 'N/A';
            } else {
                pad.button.click();
                pad.nextState = 'playing';
                clicked.text += 'playing';
            }
        } else {
            if (!pad.updateBeat) {
                clicked.text += 'you should use + to record & Backspace to reset';
                pad.state = 'N/A'
            }
            clicked.text += 'paused';
            pad.nextState = 'paused';
            pad.button.click();
        }//**** validate this, make more visible the recording part, the beat part (1-2-3-4, number of bars)
        deleteClickedInstrument(clicked);
        delete clicked.action;
    }
    if (clicked.action != null && clicked.action.name == 'delete') {
        log('cA seen here');
        switch (true) {
            case (clicked.hasOwnProperty('instrument')):
                clicked.text = clicked.instrument.name + ' cleaned';
                cleanLoop(clicked.instrument.pad);
                deleteClickedInstrument(clicked);
                break;
            case (clicked.hasOwnProperty('section')):
                clicked.text = clicked.section.name + ' pause not handled yet';
                delete clicked.section;
                break;
            case (clicked.hasOwnProperty('continuo')):
                clicked.continuo.pause = clicked.continuo.pause ? false : true;
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
        if (clicked.instrument) {
            if (clicked.instrument.level) {
                clicked.instrument.toggleMute();
                clicked.text = clicked.instrument.keyboard + (clicked.instrument.isMuted() ? ' muted' : ' unmuted');
                updatePadLabel(clicked.instrument.pad);
            }
            delete clicked.instrument;
            delete clicked.action;
        } else {
            config.engaged = config.engaged ? false : true;
            clicked.text = config.engaged ? 'tamperMod engaged' : 'tamperMod disengaged'; //*** not really though, need to set all volumes to 0, maybe found a restore also
            delete clicked.action;
        }
    }
    if (clicked.action != null && (clicked.action.name == 'increaseActionSpan' || clicked.action.name == 'decreaseActionSpan')) {
        actionSpan = clicked.action.name == 'increaseActionSpan' ? actionSpan + 1 : Math.max(0, actionSpan - 1);
        clicked.text = 'action spans on ' + actionSpan + ' bars, ';
        delete clicked.action;
    }
    if (clicked.action != null && (clicked.action.name == 'increaseVolume' || clicked.action.name == 'decreaseVolume')) {
        for (let inst of Object.values(instruments)) {
            let changeVolume = false;
            changeVolume = (clicked.instrument && clicked.instrument.name == inst.name);
            changeVolume = changeVolume || (clicked.section && clicked.continuo && inst.section.name == clicked.section.name && inst.continuo.name == clicked.continuo.name);
            changeVolume = changeVolume || (!clicked.section && clicked.continuo && inst.continuo.name == clicked.continuo.name);
            changeVolume = changeVolume || (clicked.section && !clicked.continuo && inst.section.name == clicked.section.name);
            //**** changeVolume true -> update instrument (it looks like a similar selection than for highlight box if needed)
        }
    }
    if (clicked.action != null && clicked.action.name == 'transfer' && clicked.instrument) {
        if (clicked.instrument.pad) {
            let pad = clicked.instrument.pad;
            let raw = pads[pad.bars + 'raw'];
            log('pad ' + pad.code + ' : ' + pad.bars + 'raw', 'cA');
            log(raw, 'cA');
            let instrumentName = clicked.instrument.name;
            if (pad && raw && pad.kind != 'raw') {
                let originKey = raw.keyboard;
                let destinationKey = clicked.instrument.keyboard;
                log(raw.button.style.backgroundPosition, 'cA');
                if (raw.button.style.backgroundPosition != raw.clickedStyle) {
                    raw.button.click();
                    log('clicked on raw', 'cA')
                }
                cleanLoop(pad);
                startLoop(pad);
                pad.state = 'recording';
                pad.nextState = 'playing';
                pad.stateStartTime = Date.now(); //instant recording
                pad.stateEndTime = pad.stateStartTime + pad.bars * 4 * 60 / bpm * 1000; //ms and after 4 * pad.bars it should stop recording
                setTimeout(function () {
                    cleanLoop(raw, pad.bars);
                    clicked.text = 'complete transfer of raw ' + originKey + ' to loop ' + destinationKey + ' and clean up';
                    updateTitle(clicked);
                }, pad.bars * 4 * 60 / bpm * 1000); //**** is this timing too strict ? does it have the right length */
                clicked.text = 'transferring raw ' + pad.bars + ' to ' + instrumentName + ' and cleaning it afterwards';
                delete clicked.action;
                deleteClickedInstrument(clicked);
            } else {
                if (typeof raw != "object") {
                    clicked.text = 'transfer failed: no matching ' + pad.bars + ' bars raw looper available to match destination ' + clicked.instrument.keyboard;
                }
                if (pad.kind == 'raw') {
                    clicked.text = 'transfer failed: the destination ' + clicked.instrument.keyboard + ' cannot be a raw looper';
                }
                delete clicked.action;
                deleteClickedInstrument(clicked);
            }
        } else {
            delete clicked.action;
            clicked.text = 'transfer failed: the destination ' + clicked.instrument.keyboard + ' has no associated looper';
            deleteClickedInstrument(clicked);
        }
    }
    return true;
}

function setEventListeners() {
    var clicked, target;
    clicked = {};
    document.addEventListener('mouseup', function (e) {
        //x = e.pageX;
        //y = e.pageY;
        target = e.target;
        if (e.button == 1) { //middle click - the only one I can overload without disturbing anyone
            target = target.getAttribute('mod-port');
            if (clicked && !target) {
                clicked = {};
                page_title.innerHTML = page_title_original;
                page_title.style.color = "#999";
            }
            if (target) {
                log('you clicked on: ' + target);
                clicked.newInstrument = {};
                clicked.newInstrument.instance = target.slice(0, target.lastIndexOf('/'));
                clicked.newInstrument.symbol = target.slice(target.lastIndexOf('/') + 1);
                clicked.action = 'setup instrument';
            }
            updateTitle(clicked);
        }
    }, false);
    // https://stackoverflow.com/questions/2601097/how-to-get-the-mouse-position-without-events-without-moving-the-mouse
    //press 'a' for toggling the gain on/off
    document.addEventListener('keydown', function (keyEvent) { //https://javascript.info/keyboard-events
        var conf, fade_direction, id, knob, period, port, instNumber;
        log(keyEvent.code + ' key was pressed.', 10);
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
                if (clicked.instrument.level) {
                    highlight(clicked.instrument.level);
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
}

function getPedalboardInfo() {
    var pedals = document.querySelectorAll('[class="mod-pedal ui-draggable"]');
    var types = {};
    pedals.forEach(function (pedal) { console.log(pedal.getAttribute('mod-instance').substr(7)); });
    pedals.forEach(function (pedal) {
        var type = pedal.getAttribute('mod-instance').substr(7).replace(/_\d+$/, "");
        if (types.hasOwnProperty(type)) { types[type]++; } else { types[type] = 1; console.log('new type found: ' + type); }
    });
    console.log(pedals.length + ' pedals being used');
    console.log(types);
}

(function () {
    'use strict';
    log('TamperMod is waiting to load its configuration');
    var si_id = setInterval(function () { //only loadConfiguration once the pedalboard is fully loaded
        if (document.getElementsByClassName('screen-loading blocker')[0].style.display == 'none') {
            clearInterval(si_id);
            setTimeout(function () {
                getPedalboardInfo();
                buildConfigAndActions();
                setEventListeners();
            }, 3000);
        }
    }, 2000);
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