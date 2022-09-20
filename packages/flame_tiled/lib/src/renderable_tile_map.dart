import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/src/flame_tsx_provider.dart';
import 'package:flame_tiled/src/renderable_layers/group_layer.dart';
import 'package:flame_tiled/src/renderable_layers/image_layer.dart';
import 'package:flame_tiled/src/renderable_layers/object_layer.dart';
import 'package:flame_tiled/src/renderable_layers/renderable_layer.dart';
import 'package:flame_tiled/src/renderable_layers/tile_layer.dart';
import 'package:flutter/painting.dart';
import 'package:tiled/tiled.dart' as tiled;

/// {@template _renderable_tiled_map}
/// This is a wrapper over Tiled's [tiled.TiledMap] which can be rendered to a
/// canvas.
///
/// Internally each layer is wrapped with a [RenderableLayer] which handles
/// rendering and caching for supported layer types:
///  - [tiled.TileLayer] is supported with pre-computed SpriteBatches
///  - [tiled.ImageLayer] is supported with [paintImage]
///
/// This also supports the following properties:
///  - [tiled.TiledMap.backgroundColor]
///  - [tiled.Layer.opacity]
///  - [tiled.Layer.offsetX]
///  - [tiled.Layer.offsetY]
///  - [tiled.Layer.parallaxX] (only supported if [Camera] is supplied)
///  - [tiled.Layer.parallaxY] (only supported if [Camera] is supplied)
///
/// {@endtemplate}
class RenderableTiledMap {
  /// [tiled.TiledMap] instance for this map.
  final tiled.TiledMap map;

  /// Layers to be rendered, in the same order as [tiled.TiledMap.layers]
  final List<RenderableLayer> renderableLayers;

  /// The target size for each tile in the tiled map.
  final Vector2 destTileSize;

  /// Camera used for determining the current viewport for layer rendering.
  /// Optional, but required for parallax support
  Camera? camera;

  /// Paint for the map's background color, if there is one
  late final ui.Paint? _backgroundPaint;

  /// {@macro _renderable_tiled_map}
  RenderableTiledMap(
    this.map,
    this.renderableLayers,
    this.destTileSize, {
    this.camera,
  }) {
    _refreshCache();

    final backgroundColor = _parseTiledColor(map.backgroundColor);
    if (backgroundColor != null) {
      _backgroundPaint = ui.Paint();
      _backgroundPaint!.color = backgroundColor;
    } else {
      _backgroundPaint = null;
    }
  }

  /// Changes the visibility of the corresponding layer, if different
  void setLayerVisibility(int layerId, bool visibility) {
    if (map.layers[layerId].visible != visibility) {
      map.layers[layerId].visible = visibility;
      _refreshCache();
    }
  }

  /// Gets the visibility of the corresponding layer
  bool getLayerVisibility(int layerId) {
    return map.layers[layerId].visible;
  }

  /// Changes the Gid of the corresponding layer at the given position,
  /// if different
  void setTileData({
    required int layerId,
    required int x,
    required int y,
    required tiled.Gid gid,
  }) {
    final layer = map.layers[layerId];
    if (layer is tiled.TileLayer) {
      final td = layer.tileData;
      if (td != null) {
        if (td[y][x].tile != gid.tile ||
            td[y][x].flips.horizontally != gid.flips.horizontally ||
            td[y][x].flips.vertically != gid.flips.vertically ||
            td[y][x].flips.diagonally != gid.flips.diagonally) {
          td[y][x] = gid;
          _refreshCache();
        }
      }
    }
  }

  /// Gets the Gid  of the corresponding layer at the given position
  tiled.Gid? getTileData({
    required int layerId,
    required int x,
    required int y,
  }) {
    final layer = map.layers[layerId];
    if (layer is tiled.TileLayer) {
      return layer.tileData?[y][x];
    }
    return null;
  }

  /// Parses a file returning a [RenderableTiledMap].
  ///
  /// NOTE: this method looks for files under the path "assets/tiles/".
  static Future<RenderableTiledMap> fromFile(
    String fileName,
    Vector2 destTileSize, {
    Camera? camera,
  }) async {
    final contents = await Flame.bundle.loadString('assets/tiles/$fileName');
    return fromString(contents, destTileSize, camera: camera);
  }

  /// Parses a string returning a [RenderableTiledMap].
  static Future<RenderableTiledMap> fromString(
    String contents,
    Vector2 destTileSize, {
    Camera? camera,
  }) async {
    final map = await tiled.TiledMap.fromString(
      contents,
      FlameTsxProvider.parse,
    );
    return fromTiledMap(map, destTileSize, camera: camera);
  }

  /// Parses a [tiled.TiledMap] returning a [RenderableTiledMap].
  static Future<RenderableTiledMap> fromTiledMap(
    tiled.TiledMap map,
    Vector2 destTileSize, {
    Camera? camera,
  }) async {
    final renderableLayers =
        await _renderableLayers(map.layers, null, map, destTileSize, camera);

    return RenderableTiledMap(
      map,
      renderableLayers,
      destTileSize,
      camera: camera,
    );
  }

  static Future<List<RenderableLayer<tiled.Layer>>> _renderableLayers(
    List<tiled.Layer> layers,
    GroupLayer? parent,
    tiled.TiledMap map,
    Vector2 destTileSize,
    Camera? camera,
  ) async {
    return Future.wait(
      layers.where((layer) => layer.visible).toList().map((layer) async {
        switch (layer.runtimeType) {
          case tiled.TileLayer:
            return TileLayer.load(
              layer as tiled.TileLayer,
              parent,
              map,
              destTileSize,
            );
          case tiled.ImageLayer:
            return ImageLayer.load(
              layer as tiled.ImageLayer,
              parent,
              camera,
              map,
              destTileSize,
            );

          case tiled.Group:
            final groupLayer = layer as tiled.Group;
            final renderableGroup = GroupLayer(
              groupLayer,
              parent,
              map,
              destTileSize,
            );
            final children = _renderableLayers(
              groupLayer.layers,
              renderableGroup,
              map,
              destTileSize,
              camera,
            );
            renderableGroup.children = await children;
            return renderableGroup;

          case tiled.ObjectGroup:
            return ObjectLayer.load(
              layer as tiled.ObjectGroup,
              map,
              destTileSize,
            );

          default:
            assert(false, '$layer layer is unsupported.');
            return UnsupportedLayer(layer, parent, map, destTileSize);
        }
      }),
    );
  }

  /// Handle game resize and propagate it to renderable layers
  void handleResize(Vector2 canvasSize) {
    for (final layer in renderableLayers) {
      layer.handleResize(canvasSize);
    }
  }

  /// Rebuilds the cache for rendering
  void _refreshCache() {
    for (final layer in renderableLayers) {
      layer.refreshCache();
    }
  }

  /// Renders each renderable layer in the same order specified by the Tiled map
  void render(Canvas c) {
    if (_backgroundPaint != null) {
      c.drawPaint(_backgroundPaint!);
    }

    // Paint each layer in reverse order, because the last layers should be
    // rendered beneath the first layers
    for (final layer in renderableLayers.where((l) => l.visible)) {
      layer.render(c, camera);
    }
  }

  /// Returns a layer of type [T] with given [name] from all the layers
  /// of this map. If no such layer is found, null is returned.
  T? getLayer<T extends tiled.Layer>(String name) {
    try {
      // layerByName will searches recursively starting with tiled.dart v0.8.5
      return map.layerByName(name) as T;
    } on ArgumentError {
      return null;
    }
  }
}

Color? _parseTiledColor(String? tiledColor) {
  int? colorValue;
  if (tiledColor?.length == 7) {
    // parse '#rrbbgg'  as hex '0xaarrggbb' with the alpha channel on full
    colorValue = int.tryParse(tiledColor!.replaceFirst('#', '0xff'));
  } else if (tiledColor?.length == 9) {
    // parse '#aarrbbgg'  as hex '0xaarrggbb'
    colorValue = int.tryParse(tiledColor!.replaceFirst('#', '0x'));
  }
  if (colorValue != null) {
    return Color(colorValue);
  } else {
    return null;
  }
}
