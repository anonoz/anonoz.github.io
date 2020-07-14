---
layout: post
title: How to make friendly_id mass migration faster? Skip all the callbacks.
date: 2020-07-08
category: tech
---

**Update:** Thanks to the comments in the [r/rails](https://www.reddit.com/r/rails/comments/hndvj5/how_to_make_friendly_id_backfilling_migration), I took some of the ideas, implemented them to make this runs faster. Before this, it took about an hour to backfill the column. After using `find_in_batches` and `update_columns`, it now takes half the time it took before. Posting on reddit is a good way to source more good ideas indeed!

**Update 2:** At the end I decided not to put backfilling in db migration. I have divided the friendly_id rollout into few phases:

1. Implement `#slug_candidate` for the model classes, with `ActiveRecord::Base#slug_candidate` defined as `SecureRandom.uuid`;
2. Create migration to add `slug` column;
3. A rake task to backfill;
4. After all these are done, another migration to add index to incur less performance penalty on backfilling.

____
<br>
I am currently working on integrating friendly_id gem into some of the models in [Talenox](https://www.talenox.com/?utm_source=anonozblog&utm_medium=blog&utm_campaign=friendly-id-post). Basically, it makes our in app URLs look nicer with human and company names in front, instead of just incremental primary key IDs. Oh boy... `Employee.all.each(&:save)` is fucking slow in production.

There are several things that can cause update and insert to slow down a lot for an ActiveRecord model:

1. Validations - especially when it involves multiple models
2. Callbacks - especially when they cause a chain of callbacks in other models
3. `belongs_to :parent, touch: true` - technically a callback to bust russian doll caches, but adding a slug does not necessitate busting caches

Guess what, we can skip all those. How? **By backfilling with an empty model class.**

Assuming we have an `Employee` model with a relation `employees`, this is how the migration file initially would look like:-

```ruby
# BAD
class AddFriendlyIdToEmployees < ActiveRecord::Migration[5.0]
  def up
    print "Updating friendly_id slug for employees"
    Employee.where(slug: nil).each do |row|
      row.save; print('.')
    end
    puts ''
  end
end

```

What you can do is: Create an ActiveRecord model class in that migration class with none of the callbacks EXCEPT friendly_id and `slug_candidate` method. So there won't be any callbacks being run when the object is created when fetched from database.

```ruby
# GOOD
class AddFriendlyIdToEmployees < ActiveRecord::Migration[5.0]

  # Using a blank class allows us to easily skip all callbacks that can make
  # mass migration slow.
  class Employee < ActiveRecord::Base
    self.table_name = 'employees'
    extend FriendlyId
    friendly_id :slug_candidate, use: [:slugged, :finders]

    def slug_candidate
      if first_name || last_name
        "#{first_name} #{last_name}"[0, 20]
      else
        "employee"
      end + " #{SecureRandom.hex[0, 8]}"
    end
  end

  def up
  end

  def down
  end
end
```

In the `up/down` methods, we can use `find_in_batches` to not instantiate all objects in one shot, and `update_columns` to prevent all validations and callbacks from being run.

```ruby
  def up
    add_column :employees, :slug, :text

    print "Backfilling friendly_id slug for employees"
    Employee.find_in_batches(batch_size: 100) do |batch|
      Employee.transaction do
        batch.each do |row|
          row.update_columns(
            slug: row.send(:slug_candidate).parameterize)
          print '.'
        end
        print '_'
      end
    end
    puts ' done!'

    add_index :employees, :slug, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :employees, :slug
    remove_column :employees, :slug
  end
```

However, I couldn't get the friendly_id history plug in to work properly yet. friendly_id history is implemented using ActiveRecord polymorphic. When the backfilling migration above is run, it will end up creating FriendlyId::Slug records with sluggable type of `BackfillEmployeesWithFriendlyId::FriendlyIdEmployee` instead of `Employee`. That also means you can't do subclassing of ActiveRecord models with friendly_id and expect history to work. Luckily we don't need it.
