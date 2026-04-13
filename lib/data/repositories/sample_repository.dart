import '../models/sample_item.dart';
import 'base_repository.dart';

/// Fetches/transforms [SampleItem] — swap implementation for real Firebase/API.
class SampleRepository extends BaseRepository {
  const SampleRepository();

  Future<List<SampleItem>> fetchItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      SampleItem(id: '1', title: 'First item'),
      SampleItem(id: '2', title: 'Second item'),
    ];
  }
}
