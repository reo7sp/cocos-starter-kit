module.exports = class extends cc.Scene
  onEnter: ->
    super

    label = new cc.LabelTTF('It works!')
    label.setNormalizedPosition(0.5, 0.5)
    @addChild label