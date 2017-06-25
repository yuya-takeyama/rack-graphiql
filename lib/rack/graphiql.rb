require 'rack/graphiql/version'
require 'erb'
require 'json'

module Rack
  class GraphiQL
    GRAPHIQL_VERSION     = '0.10.2'
    FETCH_VERSION        = '2.0.1'
    REACT_VERSION        = '15.5.4'
    REACT_DOM_VERSION    = '15.5.4'

    include ERB::Util

    def initialize(endpoint:)
      @endpoint = endpoint
      @template = ERB.new(open(__FILE__).read.split("__END__\n").last)
    end

    def call(env)
      req = Rack::Request.new(env)
      graphiql_query = req.params['query']
      graphiql_variables = begin
                             JSON.pretty_generate(JSON.parse(req.params['variables']))
                           rescue JSON::ParserError
                             ''
                           end
      graphiql_operation_name = req.params['operationName']
      [200, {'Content-Type' => 'text/html'}, [@template.result(binding)]]
    end

    private

    def endpoint
      @endpoint
    end

    def graphiql_version
      GRAPHIQL_VERSION
    end

    def fetch_version
      FETCH_VERSION
    end

    def react_version
      REACT_VERSION
    end

    def react_dom_version
      REACT_DOM_VERSION
    end
  end
end

__END__
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>GraphiQL</title>
  <meta name="robots" content="noindex" />
  <meta name="graphiql-endpoint" content="<%=h endpoint %>" />
  <meta name="graphiql-query" content="<%=h graphiql_query %>" />
  <meta name="graphiql-variables" content="<%=h graphiql_variables %>" />
  <meta name="graphiql-operation-name" content="<%=h graphiql_operation_name %>" />
  <style>
    html, body {
      height: 100%;
      margin: 0;
      overflow: hidden;
      width: 100%;
    }
  </style>
  <link href="//cdn.jsdelivr.net/graphiql/<%=h graphiql_version %>/graphiql.css" rel="stylesheet" />
  <script src="//cdn.jsdelivr.net/fetch/<%=h fetch_version %>/fetch.min.js"></script>
  <script src="//cdn.jsdelivr.net/react/<%=h react_version %>/react.min.js"></script>
  <script src="//cdn.jsdelivr.net/react/<%=h react_dom_version %>/react-dom.min.js"></script>
  <script src="//cdn.jsdelivr.net/graphiql/<%=h graphiql_version %>/graphiql.min.js"></script>
</head>
<body>
  <script>
    // Collect the URL parameters
    var parameters = {};
    window.location.search.substr(1).split('&').forEach(function (entry) {
      var eq = entry.indexOf('=');
      if (eq >= 0) {
        parameters[decodeURIComponent(entry.slice(0, eq))] =
          decodeURIComponent(entry.slice(eq + 1));
      }
    });

    var endpoint = document.querySelector('meta[name=graphiql-endpoint]').attributes.content.value;

    function locationURL(params) {
      return endpoint + locationQuery(params);
    }

    // Produce a Location query string from a parameter object.
    function locationQuery(params) {
      return '?' + Object.keys(params).map(function (key) {
        return encodeURIComponent(key) + '=' +
          encodeURIComponent(params[key]);
      }).join('&');
    }

    // Derive a fetch URL from the current URL, sans the GraphQL parameters.
    var graphqlParamNames = {
      query: true,
      variables: true,
      operationName: true
    };

    var otherParams = {};
    for (var k in parameters) {
      if (parameters.hasOwnProperty(k) && graphqlParamNames[k] !== true) {
        otherParams[k] = parameters[k];
      }
    }
    var fetchURL = locationURL(otherParams);

    // Defines a GraphQL fetcher using the fetch API.
    function graphQLFetcher(graphQLParams) {
      return fetch(fetchURL, {
        method: 'post',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(graphQLParams),
        credentials: 'include',
      }).then(function (response) {
        return response.text();
      }).then(function (responseBody) {
        try {
          return JSON.parse(responseBody);
        } catch (error) {
          return responseBody;
        }
      });
    }

    // When the query and variables string is edited, update the URL bar so
    // that it can be easily shared.
    function onEditQuery(newQuery) {
      parameters.query = newQuery;
      updateURL();
    }

    function onEditVariables(newVariables) {
      parameters.variables = newVariables;
      updateURL();
    }

    function onEditOperationName(newOperationName) {
      parameters.operationName = newOperationName || '';
      updateURL();
    }

    function updateURL() {
      history.replaceState(null, null, locationQuery(parameters));
    }

    var query = document.querySelector('meta[name=graphiql-query]').attributes.content.value;
    var variables = document.querySelector('meta[name=graphiql-variables]').attributes.content.value;
    var operationName = document.querySelector('meta[name=graphiql-operation-name]').attributes.content.value;

    // Render <GraphiQL /> into the body.
    ReactDOM.render(
      React.createElement(GraphiQL, {
        fetcher: graphQLFetcher,
        onEditQuery: onEditQuery,
        onEditVariables: onEditVariables,
        onEditOperationName: onEditOperationName,
        query: query || undefined,
        variables: variables,
        operationName: operationName,
      }),
      document.body
    );
  </script>
</body>
</html>
