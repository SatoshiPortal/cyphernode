const featureCondition = function(props) {
  return props.features && props.features.indexOf( 'opentimestamps' ) != -1;
}

module.exports = function( utils ) {
  return [];
};