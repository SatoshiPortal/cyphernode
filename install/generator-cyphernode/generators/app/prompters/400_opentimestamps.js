
const name = 'opentimestamps';
const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
}

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [];
  }
};