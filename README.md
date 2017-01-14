# cocos-starter-kit
Boilerplate for cocos2d-x games

## Usage
```sh
npm install -g yo gulp-cli generator-cocos-starter-kit

yo cocos-starter-kit
gulp
```

## Commands
`gulp` starts default scene of the game in browser and continuously rebuilds sources on file changes

`gulp --scene SceneName` starts particular scene of the game

`gulp test` runs tests

## Generators
`gulp new:model --name ModelName` generates new [kaniku](https://github.com/reo7sp/kaniku) model in folder `src/models`

`gulp new:controller --name ControllerName` generates new [kaniku](https://github.com/reo7sp/kaniku) controller in folder `src/scenes`

`gulp new:scene --name SceneName` generates new plain cocos2d-x scene in folder `src/scenes`

`gulp new:view --name SceneName` and `gulp new:widget --name SceneName` generates new cocos2d-x node in folder `src/widgets`

`gulp new:test --name TestName` generates new test in folder `test`
