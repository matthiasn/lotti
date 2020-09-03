import {Entity, PrimaryGeneratedColumn, Column, BaseEntity} from 'typeorm'
import {Index} from 'typeorm/index'

@Entity({name: 'entry'})
export class ORMEntry extends BaseEntity {
  @PrimaryGeneratedColumn()
  id: number | undefined

  @Column()
  entryJson: string = ''

  @Column()
  @Index()
  timestamp: number = 0
}
